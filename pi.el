;;; pi.el --- Emacs UI for Pi -*- lexical-binding: t -*-

;; Copyright (C) 2026 Anantha Kumaran.

;; Author: Anantha kumaran <ananthakumaran@gmail.com>
;; URL: http://github.com/ananthakumaran/pi.el
;; Version: 0.1
;; Keywords: pi agent
;; Package-Requires: ((emacs "28.1"))

;; This program is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by

;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;; Commentary:

;;; Code:

(require 'project)

(defgroup pi nil
  "Emacs UI for Pi."
  :prefix "pi-"
  :group 'tools)

(defcustom pi-sync-request-timeout 2
  "The number of seconds to wait for a sync response."
  :type 'integer
  :group 'pi)

(defcustom pi-executable "pi"
  "Pi command executable name."
  :type 'string
  :group 'pi)

(defcustom pi-process-environment '()
  "List of extra environment variables to use when starting pi."
  :type '(repeat string)
  :group 'pi)

(defcustom pi-flags '()
  "List of additional flags to provide when starting pi."
  :type '(repeat string)
  :group 'pi)


(defmacro pi-def-permanent-buffer-local (name &optional init-value)
  "Declare NAME as buffer local variable."
  `(progn
     (defvar ,name ,init-value)
     (make-variable-buffer-local ',name)
     (put ',name 'permanent-local t)))

(defun pi-join (list)
  (mapconcat 'identity list ""))

(pi-def-permanent-buffer-local pi-project-root nil)

(defvar pi-agents (make-hash-table :test 'equal))
(defvar pi-chats (make-hash-table :test 'equal))
(defvar pi-response-callbacks (make-hash-table :test 'equal))

(defun pi-project-root ()
  (or
   pi-project-root
   (let ((project (project-current))
         (path default-directory))
     (if project
         (setq path (project-root project))
       (message (pi-join (list "Couldn't find project root folder. Using '" default-directory "' as project root."))))
     (let ((full-path (expand-file-name path)))
       (setq pi-project-root full-path)
       full-path))))

(defun pi-project-name ()
  (let ((full-path (directory-file-name (pi-project-root))))
    (concat (file-name-nondirectory full-path) "-" (substring (md5 full-path) 0 10))))


;;; Helpers

(defun pi-json-read-object ()
  (json-parse-buffer :object-type 'plist :null-object json-null :false-object json-false :array-type 'list))

(defun pi-json-encode (obj)
  "Encode OBJ into a JSON string. JSON arrays must be represented with vectors."
  (json-serialize obj :null-object json-null :false-object json-false))

;;; Events

(defvar pi-event-listeners (make-hash-table :test 'equal))

(defun pi-set-event-listener (listener)
  (puthash (pi-project-name) (cons (current-buffer) listener) pi-event-listeners))

;;; Agent

(defvar pi-agent-buffer-name "*pi-agent*")
(defvar pi-chat-buffer-name "*pi-chat*")
(defvar pi-agents (make-hash-table :test 'equal))
(defvar pi-request-counter 0)

(defun pi-current-agent ()
  (gethash (pi-project-name) pi-agents))

(defun pi-next-request-id ()
  (number-to-string (cl-incf pi-request-counter)))

(defun pi-dispatch-response (response)
  (let* ((request-id (plist-get response :id))
         (callback (gethash request-id pi-response-callbacks)))
    (when callback
      (let ((buffer (car callback)))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (apply (cdr callback) (list response)))))
      (remhash request-id pi-response-callbacks))))

(defun pi-dispatch-event (event)
  (-when-let (listener (gethash (pi-project-name) pi-event-listeners))
    (with-current-buffer (car listener)
      (apply (cdr listener) (list event)))))

(defun pi-dispatch (response)
  (cl-case (intern (plist-get response :type))
    ((response) (pi-dispatch-response response))
    ((event) (pi-dispatch-event response)
     t (message "Unexpected message from agent: %S" response))))

(defun pi-send-command (type args &optional callback)
  (unless (pi-current-agent)
    (error "Agent does not exist. Run M-x pi-restart-agent to start it again"))

  (let* ((request-id (pi-next-request-id))
         (command (append (list :id request-id :type type) args))
         (encoded-command (pi-json-encode command))
         (payload (concat encoded-command "\n")))
    (process-send-string (pi-current-agent) payload)
    (when callback
      (puthash request-id (cons (current-buffer) callback) pi-response-callbacks))))

(defun pi-seconds-elapsed-since (time)
  (time-to-seconds (time-subtract (current-time) time)))

(defun pi-send-command-sync (name args)
  (let* ((start-time (current-time))
         (response nil))
    (pi-send-command name args (lambda (resp) (setq response resp)))
    (while (not response)
      (accept-process-output nil 0.01)
      (when (> (pi-seconds-elapsed-since start-time) pi-sync-request-timeout)
        (error "Sync request timed out %s" name)))
    response))

(defun pi-net-sentinel (process message)
  (let ((project-name (process-get process 'project-name)))
    (message "(%s) pi exits: %s." project-name (string-trim message))
    (ignore-errors
      (kill-buffer (process-buffer process)))
    (pi-cleanup-project project-name)))

(defun pi-net-filter (process data)
  (with-current-buffer (process-buffer process)
    (goto-char (point-max))
    (insert (format "%s" data)))
  (pi-decode-response process))

(defun pi-enough-response-p ()
  (goto-char (point-min))
  (save-excursion
    (when (search-forward "{")
      (search-forward "\n" nil t))))

(defun pi-decode-response (process)
  (with-current-buffer (process-buffer process)
    (when (pi-enough-response-p)
      (search-forward "{")
      (backward-char 1)
      (let ((response (pi-json-read-object)))
        (delete-region (point-min) (point))
        (when response
          (pi-dispatch response)))
      (when (>= (buffer-size) 16)
        (pi-decode-response process)))))

(defun pi-start-agent ()
  (when (pi-current-agent)
    (error "Agent already exist"))

  (message "(%s) Starting pi..." (pi-project-name))
  (let* ((default-directory (pi-project-root))
         (process-environment (append pi-process-environment process-environment))
         (buf (generate-new-buffer pi-agent-buffer-name))
         ;; Use a pipe to communicate with the subprocess. This fixes a hang
         ;; when a >1k message is sent on macOS.
         (process-connection-type nil)
         (process-arguments (append pi-flags '("--mode" "rpc")))
         (process
          (apply #'start-file-process "pi" buf pi-executable process-arguments)))
    (set-process-coding-system process 'utf-8-unix 'utf-8-unix)
    (set-process-filter process #'pi-net-filter)
    (set-process-sentinel process #'pi-net-sentinel)
    (set-process-query-on-exit-flag process nil)
    (with-current-buffer (process-buffer process)
      (buffer-disable-undo))
    (process-put process 'project-name (pi-project-name))
    (process-put process 'project-root default-directory)
    (puthash (pi-project-name) process pi-agents)
    (message "(%s) pi agent started successfully." (pi-project-name))))


(defun pi-cleanup-project (project-name)
  (remhash project-name pi-agents)
  (remhash project-name pi-event-listeners))

(defun pi-cleanup-chat-buffer ()
  (let ((project-name (pi-project-name)))
    (ignore-errors
      (pi-kill-agent))
    (remhash project-name pi-chats)))

;;; Utility commands

(defun pi-kill-agent ()
  "Kill the agent in the current buffer."
  (interactive)
  (-when-let (agent (pi-current-agent))
    (delete-process agent)))

(defun pi-restart-agent ()
  "Restarts pi agent."
  (interactive)
  (pi-kill-agent)
  (pi-start-agent))


;;; Chat

(defun pi-current-chat ()
  (gethash (pi-project-name) pi-chats))

(define-derived-mode pi-chat-mode special-mode "pi-chat"
  "Major mode for pi chat.

\\{pi-chat-mode-map}"
  (message "chat mode")
  (add-hook 'kill-buffer-hook 'pi-cleanup-chat-buffer nil t))

(defvar pi-chat-mode-map
  (let ((map (make-sparse-keymap)))
    map))

(defun pi-chat ()
  "Start a chat window"
  (interactive)
  (let ((chat-buffer (or (pi-current-chat)
                         (progn
                           (let ((buffer (generate-new-buffer pi-chat-buffer-name))
                                 (root (pi-project-root)))
                             (with-current-buffer buffer
                               (pi-chat-mode)
                               (setq-local default-directory root))
                             (puthash (pi-project-name) buffer pi-chats)
                             buffer)))))
    (pop-to-buffer chat-buffer))
  (unless (pi-current-agent)
    (pi-start-agent)))

;;; Commands

(defun pi-command:get-session-stats ()
  (interactive)
  (let ((inhibit-read-only t))
    (insert (format "%S" (pi-send-command-sync "get_session_stats" '())))))


(provide 'pi)

;;; pi.el ends here
