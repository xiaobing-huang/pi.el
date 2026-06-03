;;; pi-tests --- This file contains automated tests for pi.el -*- lexical-binding: t; -*-

;;; Code:

;; Test setuup:

(require 'ert)

;; development only packages, not declared as a package-dependency
(package-initialize)

(ert-deftest pi-hello-tests ()
  (should (equal t t)))

(require 'pi)

(ert-deftest pi-parse-slash-command ()
  (should (equal (pi-parse-slash-command "/model") '(pi-select-model . nil)))
  (should (equal (pi-parse-slash-command "/new") '(pi-new-session . nil)))
  (should (equal (pi-parse-slash-command "/resume") '(pi-resume . nil)))
  (should (equal (pi-parse-slash-command "/compact") '(pi-compact . nil)))
  (should (equal (pi-parse-slash-command "/compact custom instructions") '(pi-compact . "custom instructions")))
  (should (equal (pi-parse-slash-command "  /model") '(pi-select-model . nil)))
  (should (equal (pi-parse-slash-command "/model ") '(pi-select-model . nil)))
  (should (null (pi-parse-slash-command "/unknown")))
  (should (null (pi-parse-slash-command "/modelx")))
  (should (null (pi-parse-slash-command "/")))
  (should (null (pi-parse-slash-command "/123")))
  (should (null (pi-parse-slash-command "not-a-slash /model")))
  (should (null (pi-parse-slash-command "")))
  (let ((err (should-error (pi-parse-slash-command "/model arg"))))
    (should (equal "Slash command \"/model\" does not accept arguments" (error-message-string err)))))

(ert-deftest pi-parse-bang-command ()
  (should (equal (pi-parse-bang-command "!ls") "ls"))
  (should (equal (pi-parse-bang-command "!ls -la") "ls -la"))
  (should (equal (pi-parse-bang-command "  !ls") "ls"))
  (should (equal (pi-parse-bang-command "! cat!") " cat!"))
  (should (null (pi-parse-bang-command "!!ls")))
  (should (null (pi-parse-bang-command "!!")))
  (should (null (pi-parse-bang-command "!")))
  (should (null (pi-parse-bang-command "! ")))
  (should (null (pi-parse-bang-command "!!  ")))
  (should (null (pi-parse-bang-command "not-a-bang !ls")))
  (should (null (pi-parse-bang-command ""))))

(ert-deftest pi-parse-double-bang-command ()
  (should (equal (pi-parse-double-bang-command "!!ls") "ls"))
  (should (equal (pi-parse-double-bang-command "!!ls -la") "ls -la"))
  (should (equal (pi-parse-double-bang-command "  !!ls") "ls"))
  (should (null (pi-parse-double-bang-command "!!")))
  (should (null (pi-parse-double-bang-command "!")))
  (should (null (pi-parse-double-bang-command "  !!")))
  (should (null (pi-parse-double-bang-command "!! ")))
  (should (null (pi-parse-double-bang-command "! ")))
  (should (null (pi-parse-double-bang-command "!ls")))
  (should (null (pi-parse-double-bang-command "not-a-bang !!ls")))
  (should (null (pi-parse-double-bang-command ""))))

;;; pi-tests.el ends here

