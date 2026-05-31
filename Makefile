export EMACS ?= $(shell command -v emacs 2>/dev/null)
CASK_DIR := $(shell cask package-directory)

$(CASK_DIR): Cask
	cask install
	@touch $(CASK_DIR)

.PHONY: cask
cask: $(CASK_DIR)

.PHONY: compile
compile: cask
	cask emacs -batch -L . -L test \
	  -f batch-byte-compile $$(cask files); \
	  (ret=$$? ; cask clean-elc && exit $$ret)

.PHONY: test
test: compile
	cask emacs --batch -L . -L test -l pi-tests.el -l pi-section-tests.el -f ert-run-tests-batch

.PHONY: format
format:
	cask emacs --batch -L . -l pi.el -l pi-section.el -l pi-tests.el -l pi-section-tests.el \
	  --eval " \
	  (progn \
            (setq-default indent-tabs-mode nil) \
	    (dolist (f command-line-args-left) \
	      (with-current-buffer (find-file-noselect f) \
                (message \"formatting %s\" f) \
	        (indent-region (point-min) (point-max)) \
	        (save-buffer))))" \
          pi.el pi-section.el pi-tests.el pi-section-tests.el
