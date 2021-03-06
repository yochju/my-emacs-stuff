;;; my-edit-server.el -- load up the Edit with Emacs edit server
;;
;;; Commentary:
;;
;; There is not much to do here but ensure the edit server is spawned
;; at the end of start-up and we have hooks in place for the various modes.
;;
;;; Code:

(require 'use-package)

(use-package my-vars)
(use-package my-web)

(use-package edit-server
  :commands edit-server-start
  :init (if after-init-time
            (edit-server-start)
          (add-hook 'after-init-hook
                  #'(lambda() (edit-server-start))))
  :config (setq edit-server-url-major-mode-alist
                (list '("stackexchange" . markdown-mode)
                      '("github.com" . markdown-mode))))

(with-eval-after-load 'edit-server
  ;; Mediawiki
  (add-to-list 'edit-server-url-major-mode-alist
               '("mediawiki" . mediawiki-mode))
  (add-to-list 'edit-server-url-major-mode-alist
               '("wikipedia" . mediawiki-mode))
  (add-to-list 'edit-server-url-major-mode-alist
               '("wiki.qemu.org" . mediawiki-mode))
  ;; Moin-moin
  (add-to-list 'edit-server-url-major-mode-alist
               '("wiki.linaro.org" . moinmoin-mode))
  ;; Web-mode
  (add-to-list 'edit-server-url-major-mode-alist
               '("www.bennee.com/~alex/blog" . web-mode))
  ;; Fallbacks for webmail
  (unless (require 'gmail-message-mode nil t)
    (add-to-list 'edit-server-url-major-mode-alist
                 '("mail.google" . mail-mode))
    ;; Rough and ready html munging
    (when (require 'edit-server-htmlize nil t)
      (add-hook 'edit-server-start-hook
                'edit-server-maybe-dehtmlize-buffer)
      (add-hook 'edit-server-done-hook
                'edit-server-maybe-htmlize-buffer)))
  ;; Final bits
  (setq edit-server-edit-mode-hook nil)
  (add-hook 'edit-server-edit-mode-hook 'flyspell-mode t))

(provide 'my-edit-server)
;;; my-edit-server.el ends here
