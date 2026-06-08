;;; pi-edit.el --- Edit mode support -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Anantha Kumaran.

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

;;; Commentary:

(require 'cl-lib)
(require 'compat)

;;; Code:

(defvar-keymap pi-edit-mode-map
  "C-c C-c"                                #'pi-edit-finish
  "<remap> <server-edit>"                  #'pi-edit-finish
  "<remap> <evil-save-and-close>"          #'pi-edit-finish
  "<remap> <evil-save-modified-and-close>" #'pi-edit-finish
  "C-c C-k"                                #'pi-edit-cancel
  "<remap> <kill-buffer>"                  #'pi-edit-cancel
  "<remap> <ido-kill-buffer>"              #'pi-edit-cancel
  "<remap> <iswitchb-kill-buffer>"         #'pi-edit-cancel
  "<remap> <evil-quit>"                    #'pi-edit-cancel)

(defvar-local pi-edit-on-complete nil)
(defvar-local pi-edit-on-cancel nil)
(defvar-local pi-edit-original-text nil)
(defvar-local pi-edit-return-window nil)

(define-derived-mode pi-edit-mode fundamental-mode "pi-edit"
  "Major mode for editing text via pi.

\\{pi-edit-mode-map}"
  (setq-local header-line-format
              (substitute-command-keys
               "Type \\[pi-edit-finish] to finish, \\[pi-edit-cancel] to cancel")))

(defun pi-edit-finish ()
  (interactive)
  (let ((text (buffer-string))
        (buffer (current-buffer))
        (callback pi-edit-on-complete)
        (window pi-edit-return-window))
    (kill-buffer buffer)
    (when (window-live-p window)
      (select-window window))
    (when callback
      (funcall callback text))))

(defun pi-edit-cancel ()
  (interactive)
  (let ((buffer (current-buffer))
        (callback pi-edit-on-cancel)
        (window pi-edit-return-window))
    (kill-buffer buffer)
    (when (window-live-p window)
      (select-window window))
    (when callback
      (funcall callback))))

(defun pi-with-editor (on-complete on-cancel &optional text)
  (let ((buffer (generate-new-buffer "*pi-edit*"))
        (window (selected-window)))
    (with-current-buffer buffer
      (pi-edit-mode)
      (when text
        (insert text)
        (goto-char (point-min)))
      (setq pi-edit-on-complete on-complete
            pi-edit-on-cancel on-cancel
            pi-edit-return-window window))
    (pop-to-buffer buffer)))

(provide 'pi-edit)

;;; pi-edit.el ends here
