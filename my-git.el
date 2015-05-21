;;; my-git.el --- My git custiomisations
;;
;;; Commentary:
;;
;; This is mostly magit configuration stuff
;;
;;; Code:

(require 'my-vars)
(require 'use-package)

; work-around stale shells
(when I-am-at-work
  (setenv "GIT_AUTHOR_EMAIL" "alex.bennee@linaro.org"))

(use-package magit
  :commands magit-status
  :bind ("C-x g" . magit-status)
  :init
  (progn
    (setq magit-last-seen-setup-instructions "1.4.0"))
  :config
  (progn
    (add-hook 'magit-mode-hook #'(lambda() (yas-minor-mode -1)))
    (add-hook 'magit-log-edit-mode-hook #'(lambda() (auto-fill-mode 1)))
    (add-hook 'magit-log-mode-hook 'my-magit-add-checkpatch-hook)
    ;; really I never use anything but git
    (setq vc-handled-backends nil)
    (setq
     magit-status-buffer-switch-function 'switch-to-buffer
     magit-rewrite-inclusive 'nil
     magit-revert-buffers 'silent)))


;;;
;; Run checkpatch.pl if we can
;;
(defvar magit-checkpatch-script nil
  "Path to local checkpatch script, if it exists.")
(make-variable-buffer-local 'magit-checkpatch-script)
(put 'magit-checkpatch-script 'permanent-local t)

(use-package compile
  :commands compilation-mode
  :config
  (progn
    ;; Match checkpatch.pl output
    (add-to-list
     'compilation-error-regexp-alist-alist
     '(checkpatch
       "\\(WARNING\\|ERROR\\).*\n#.*FILE: \\([^:]+\\):\\([^:digit:]+\\).*\n.*"
       2 ; file
       3 ; line
       ))
    ;; add reference
    (add-to-list 'compilation-error-regexp-alist 'checkpatch)))

(defun my-magit--do-run-checkpatch (commit)
  "Run the checkpatch script against `COMMIT'."
  (let ((proc-name "checkpatch")
        (buff-name (format "checkpatch-%s" commit)))
    (start-process-shell-command
     proc-name
     buff-name
     (format "git show --pretty=email %s | %s -" commit magit-checkpatch-script))
    (switch-to-buffer buff-name)
    (goto-char (point-min))
    (compilation-minor-mode)))

(defun my-magit-run-checkpatch ()
  "Run a checkpatch script against current commit."
  (interactive)
  (when (derived-mode-p 'magit-log-mode)
    (my-magit--do-run-checkpatch (magit-commit-at-point))))

(defun my-magit-add-checkpatch-hook ()
  "Add the ability to run a checkpatch script if we can."
  (let ((script (concat default-directory "scripts/checkpatch.pl")))
    (when (file-exists-p script)
      (setq magit-checkpatch-script script)
      (local-set-key (kbd "C") 'my-magit-run-checkpatch))))


;;;
;;; Additional GIT bits
;;;
(use-package git
  :commands git-status
  ; currently disabled due to magit-next
  :disabled t)

(use-package git-commit-mode
  ; currently disabled due to magit-next
  :disabled t)

(use-package git-blame
  :commands git-blame-mode)

(use-package git-messenger
  :commands git-messenger:popup-message
  :bind ("C-h g" . git-messenger:popup-message)
  :init
  (setq git-messenger:show-detail t))

(provide 'my-git)
;;; my-git.el ends here
