;;; my-company --- My personal tweaks for company-mode
;;
;; Copyright (C) 2014 Alex Bennée
;;
;; Author: Alex Bennée <alex@bennee.com>
;;
;; This file is not part of GNU Emacs.
;;
;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;;; Commentary:
;;
;; I've been using autocomplete-mode so far so this is currently
;; experimental. I thought I'd have a look after elpy moved to using company-mode.
;;
;;; Code:

;; Require prerequisites
(require 'company)

;; Variables
(setq company-selection-wrap-around t
      tab-always-indent 'complete)

;; Remove backends I'll never use
(delete 'company-bbdb company-backends)
(delete 'company-eclim company-backends)
(delete 'company-xcode company-backends)
(delete 'company-semantic company-backends)

;; company-yasnippet must be at the end of the list
;; (when (require 'company-yasnippet nil t)
;;   (add-to-list 'company-backends 'company-yasnippet t))
;(delete 'company-yasnippet company-backends)

(defvar completion-at-point-functions-saved nil
  "Saved copy of the `completion-at-point-functions'.")

;; Code
; Wrappers for company-mode to integrate with tab-always-indent's
; complete function.

(defun company-complete-common-wrapper ()
  "A simple wrapper."
  (let ((completion-at-point-functions completion-at-point-functions-saved))
    (company-complete-common)))

(defun company-indent-for-tab-command (&optional arg)
  "A company-mode wrapper for `indent-for-tab-command'.
`ARG' is passed to `indent-for-tab-command'."
  (interactive "P")
  (let ((completion-at-point-functions-saved completion-at-point-functions)
        (completion-at-point-functions '(company-complete-common-wrapper)))
    (indent-for-tab-command arg)))

; Make tab cycle through choices
(eval-after-load 'company
  '(progn
     ;; keys active while completing
     (define-key company-active-map (kbd "TAB") 'company-complete-common)
     (define-key company-active-map [tab] 'company-complete-common)
     (define-key company-active-map (kbd "<right>") 'company-complete-common)
     ;; keys active in the global minor mode
     (define-key company-mode-map (kbd "M-/") 'company-complete-common)
     (define-key company-mode-map [remap indent-for-tab-command]
       'company-indent-for-tab-command)))

;; Any other extensions?
(when (require 'company-irony nil t)
  (eval-after-load 'company
    '(progn
       (add-to-list 'company-backends 'company-irony))))

;(global-set-key (kbd "<tab>") 'indent-for-tab-command)
;(global-set-key (kbd "C-c y") 'company-yasnippet)
;(global-unset-key (kbd "C-c y"))

;; Global mode
(add-hook 'after-init-hook 'global-company-mode)

(provide 'my-company)
;;; my-company.el ends here
