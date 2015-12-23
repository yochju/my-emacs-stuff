;;; init.el --- Alex Bennée's .emacs
;;
;;; Commentary:
;;
;; This is my Emacs, there are many like it but this is my own.
;; It is mainly an amalgem of different hacks acquired over time
;; which I use on many of the machines I work with.
;;
;; It has a cobbled heritage from various sites and wikis and it is
;; probably safest to assume the code is all either GPL or Public
;; Domain.  Feel free to use whatever bits may be of use to you in these
;; files that it is my right to license ;-)
;;
;;; Code:

; debugging weird start-up issues.
;(setq debug-ignored-errors (remq 'user-error debug-ignored-errors))
;(setq debug-on-error 't)

;; Use .el if it is newer
(when (boundp 'load-prefer-newer)
  (setq load-prefer-newer t))

;; Manually load this (as paths not yet set)
;(eval-when-compile (defvar god-local-mode))
(declare-function my-add-config-paths "~/.emacs.d/my-elisp/my-paths" t t)
(when (load-library "~/.emacs.d/my-elisp/my-paths")
  (my-add-config-paths))

;;;; Start of real code.

;; Find out about my environment
(require 'my-vars)

;; For auto-testing
(defvar I-completed-loading-dotinit 'nil
  "Flag indicating succesful start-up.")

;; Packaging
(load-library "my-package.el")

;; Add ~/.emacs.d/*.git project into search path
;; They are added in-front of all other paths so will override
;; ELPA/MELPA versions
(when (fboundp 'my-add-git-project-paths)
  (my-add-git-project-paths))

(require 'my-config)

;; Load any hand-made customisation
;; we do this early to prevent problems with theme safety and the like
(when (file-exists-p custom-file)
  (load custom-file))

(require 'my-keybinds)

(require 'use-package nil t)

(use-package my-libs)

(require 'my-basic-modes)
(require 'my-display)

(use-package edit-server
  :if (and (getenv "DISPLAY") (daemonp) (not (= 0 (user-uid))))
  :commands edit-server-start
  :init (add-hook 'after-init-hook
                  #'(lambda()
                      (edit-server-start)
                      (load-library "my-edit-server.el"))))

;; Stuff I always want
;; general editing
(use-package my-editing)
;; email
(use-package my-email
  :if (file-accessible-directory-p "~/Maildir"))
;; Development related stuff, including project root
(load-library "my-devel")

(use-package my-flycheck
  :if (version<= "24.4" emacs-version))

(load-library "my-web")
(load-library "my-elisp")
(load-library "my-python")
;; Org configuration
(load-library "my-org")
;; Helm
(load-library "my-helm")
;; More keybindings
(load-library "my-toggles")
;; Window and buffer navigation
(load-library "my-windows")
(load-library "my-buffer")
(load-library "my-dired")
(load-library "my-keyhelp")

;; Locally installed pkgs
(load-library "my-local-pkgs")

;; Useful modes
(load-library "my-company")
(load-library "my-yasnippet")

;; other customisations
(load-library "my-tramp")
(load-library "my-spell")
(load-library "my-gpg")
(load-library "my-git")
(load-library "my-htmlize")
(load-library "my-eshell")
(load-library "my-circe")
(load-library "my-diff")

;; Lets use mark-tools if we can
(use-package mark-tools
  :bind ("C-x m" . list-marks))

(use-package paradox
  :ensure paradox
  :commands paradox-list-packages
  :config
  (when (my-primary-machine-p)
    (setq paradox-github-token (my-pass-password "paradox" t))))

(load "the-rest.el")

;; Finally some additional keybinds
(load "my-hydra.el")

;; Finished loading

(message "Done .emacs")

(setq I-completed-loading-dotinit 't)

(provide 'init)
;;; init.el ends here
