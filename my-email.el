;;; my-email.el --- Email set-up
;;
;;; Commentary:
;;
;; After with notmuch, mu4e and Gnus I went with mu4e mainly due to
;; speed and apparent simplicity of customisation.
;;
;;; Code:

(require 'use-package)
(require 'my-vars)
(require 'my-libs)

(use-package async
  :ensure t)

(use-package smtpmail
  :commands smtpmail-send-queued-mail
  :config
  (setq smtpmail-queue-mail  nil  ;; start in non-queuing mode
        smtpmail-queue-dir   "~/Maildir/queue/cur"
        smtpmail-default-smtp-server "localhost"
        smtpmail-smtp-server "localhost"
        smtpmail-smtp-service 25))


;; Signature
(defun my-sig-function ()
  "Generate a signature."
  (interactive)
  (concat "Alex Bennée"))

;; Simple mail-mode and message-mode hooks.
;;
;; Ostensibly they both do the same thing however message-mode (and
;; the derived mu4e-compose-mode) assume they are sending from within
;; emacs. So I'll use the convention that I'll use mail-mode for
;; edit-server spawned mails and message-mode for the rest

(defun my-common-mail-tweaks ()
  "Enable common mail tweaks for sending messages."
  (interactive)
  (turn-on-flyspell)
  (turn-on-auto-fill))

(defun my-mail-mode-tweaks()
  "Customise mail-mode stuff"
  (interactive)
  (my-common-mail-tweaks)
  (when (and
         buffer-file-name
         (or
          (string-match "/tmp/mutt" buffer-file-name)
          (string-match "gitsend" buffer-file-name)))
    (define-key (current-local-map) (kbd "C-c C-c") 'server-edit)
    (define-key (current-local-map) (kbd "C-c C-s") 'server-edit)))

(use-package sendmail
  ;; Enable mail-mode for mutt spawned files
  :mode (("/tmp/mutt-*" . mail-mode)
         ("0000-cover-letter.patch" . mail-mode)
         (".*/\.git/\.gitsendemail.MSG.*" . mail-mode))
  :config (add-hook 'mail-mode-hook 'my-mail-mode-tweaks))

(use-package message
  :commands message-mode
  :config (add-hook 'message-mode-hook 'my-common-mail-tweaks))

;; BBDB
(use-package bbdb
  :config (progn
            (setq bbdb-add-aka t
                  bbdb-layout 'one-line
                  bbdb-mua-auto-update-p 'query)
            (bbdb-initialize 'mu4e 'rmail 'gnus 'message)))

;;
;; Finally the mu4e configuration
;;
;; This is my main work horse for day to day email.
;;

;; Switch function
(defun my-switch-to-mu4e (&optional prefix)
  "Smart dwim switch to mu4e."
  (interactive "P")
  (if prefix
      (mu4e)
    (let ((candidate
           (or
            ;; unsent emails
            (car (--filter
                  (with-current-buffer it
                    (and
                     (eq major-mode 'mu4e-compose-mode)
                     (not message-sent-message-via)))
                  (buffer-list)))
            ;; current search
            (get-buffer "*mu4e-headers*")
            ;; current view
            (get-buffer "*mu4e-view*"))))
      (if candidate
          (progn
            (switch-to-buffer candidate)
            (delete-other-windows))
        (mu4e)))))

;; Jump to current thread
(defun my-switch-to-thread ()
  "Switch to headers view of current thread."
  (interactive)
  (let* ((msg (mu4e-message-at-point))
         (id (or (mu4e-message-field-raw msg :in-reply-to)
                 (mu4e-message-field-raw msg :message-id))))
    (when (> (length id) 0)
      (mu4e-headers-search (format "i:%s" (s-replace-all '(("<" . "")
                                                           (">" . ""))
                                                         id))))))

;; Set default directory when viewing messages
(defvar my-mailing-list-dir-mapping
  '( ("qemu-devel.nongnu.org" . "~/lsrc/qemu/qemu.git/")
     ("kvmarm.lists.cs.columbia.edu" . "~/lsrc/kvm/linux.git/")
     ("kvm.vger.kernel.org" . "~/lsrc/kvm/linux.git/")
     ("virtualization.lists.linux-foundation.org" . "~/lsrc/kvm/linux.git/") )
  "Mapping from mailing lists to source tree.")

(defvar my-maildir-mapping
  '( ("linaro/virtualization/qemu" . "~/lsrc/qemu/qemu.git/")
     ("linaro/virtualization/qemu-arm" . "~/lsrc/qemu/qemu.git/")
     ("linaro/virtualization/qemu-multithread" . "~/lsrc/qemu/qemu.git/")
     ("linaro/kernel" . "~/lsrc/kvm/linux.git/") )
  "Mapping from maildirs to source tree.")

(defvar my-mail-address-mapping
  ' ( ("qemu-devel@nongnu.org" . "~/lsrc/qemu/qemu.git/")
      ("kvmarm@lists.cs.columbia.edu" . "~/lsrc/kvm/linux.git/") )
    "Mapping from target address to source tree.
Useful for replies and drafts")

(defun my-get-code-dir-from-email ()
  "Return the associated code directory depending on email."
  (let* ((msg (mu4e-message-at-point t))
         (list (mu4e-message-field msg :mailing-list))
         (maildir (mu4e-message-field msg :maildir))
         (addresses (-map 'cdr (append (mu4e-message-field msg :to)
                                       (mu4e-message-field msg :cc)))))
    (expand-file-name
     (or
      (assoc-default list my-mailing-list-dir-mapping)
      (assoc-default maildir my-maildir-mapping 'string-match)
      (assoc-default (-first
                      #'(lambda (mail)
                          (assoc-default mail my-mail-address-mapping))
                      addresses) my-mail-address-mapping)
      "~"))))

(defun my-set-view-directory ()
  "Switch the `default-directory' depending mail contents."
  (interactive)
  (when (mu4e-message-at-point t)
    (setq default-directory (my-get-code-dir-from-email))))

(defun my-search-code-from-email ()
  "Search code depending on email."
  (interactive)
  (my-project-find (my-get-code-dir-from-email)))

(use-package mu4e-compose
  :commands mu4e-compose-mode
  :defines mu4e-compose-mode-map
  :config (progn
            ;; key-bindings
            (when (keymapp mu4e-compose-mode-map)
              (define-key mu4e-compose-mode-map (kbd "C-w")
                'my-snip-region)
              (define-key mu4e-compose-mode-map (kbd "<f5>")
                'my-search-code-from-email))
              (add-hook 'mu4e-compose-mode-hook 'my-set-view-directory)
            (add-hook 'mu4e-compose-pre-hook 'my-choose-mail-address)))

(use-package mu4e-headers
  :commands mu4e-headers-mode
  :defines mu4e-headers-mode-map
  :config (progn
            ;; My mode bindings
            (define-key mu4e-headers-mode-map (kbd "C-c C-l") 'org-store-link)
            (define-key mu4e-headers-mode-map (kbd "C-c t")
              'my-switch-to-thread)
            (add-hook 'mu4e-headers-mode-hook
                      '(lambda () (yas-minor-mode -1)))
            (add-hook 'mu4e-headers-mode-hook 'my-set-view-directory)))

(use-package mu4e-view
  :commands mu4e-view
  :defines mu4e-view-mode-map
  :config (progn
            ;; My mode bindings
            (define-key mu4e-view-mode-map (kbd "C-c C-l") 'org-store-link)
            (define-key mu4e-view-mode-map (kbd "C-c t") 'my-switch-to-thread)
            ;; mode hooks
            (add-hook 'mu4e-view-mode-hook 'my-set-view-directory)))

;; spam learning: ionice -c 3 sa-learn --progress --spam ~/Maildir/.Spam/cur/*

;; loosely hacked from mu4e-control.el HEAD
(defvar my-mu4e-register-spam-cmd
  "sa-learn --spam %s"
  "Command for invoking spam processor to register message as spam.")

(defvar my-mu4e-register-ham-cmd
  "sa-learn --ham %s"
  "Command for invoking spam processor to register message as ham.")

(defun my-mu4e-register-spam-action (msg)
  "Mark `MSG' as spam."
  (interactive)
  (let* ((path (shell-quote-argument
                (mu4e-message-field msg :path)))
         (command (format my-mu4e-register-spam-cmd path)))
    ;; (async-shell-command command nil))
    (start-process "LSPAM" nil "sa-learn" "--spam" path))
  (mu4e-mark-at-point 'delete nil)
  (mu4e-headers-next))


(defun my-mu4e-register-ham-action (msg)
  "Mark `MSG' as ham."
  (interactive)
  (let* ((path (shell-quote-argument
                (mu4e-message-field msg :path)))
         (command (format my-mu4e-register-ham-cmd path)))
    (async-shell-command command))
  (mu4e-mark-at-point 'something nil))

(use-package mu4e
  :commands mu4e
  ;; Bindings
  :bind ("C-c m" . my-switch-to-mu4e)
  :config
  (progn
    (require 'mu4e-vars)
    ;; config options
    (setq
     ;; generic mail options
     user-mail-address
     (cond
      (I-am-at-work  "alex.bennee@linaro.org")
      (t "alex@bennee.com"))
     user-full-name  "Alex Bennée"
     mail-signature '(insert (concat "\n--\n" (my-sig-function)))
     mail-user-agent 'mu4e-user-agent
     ;; message functions
     message-signature 'my-sig-function
     message-send-mail-function 'smtpmail-send-it
     ;; mu4e functions
     ;; mail fetch
     mu4e-get-mail-command
     (cond
      (I-am-at-work "mbsync linaro-sync")
      (t "true"))
     mu4e-update-interval 600
     mu4e-change-filenames-when-moving t ; keep mbsync happy
     ;; navigate options
     mu4e-use-fancy-chars t
     mu4e-headers-skip-duplicates t
     mu4e-headers-include-related t
     ;; compose options
     mu4e-compose-signature 'my-sig-function
     ;; this ensures completion-at-point functionality is setup
     ;; which eventually percolates to company-capf.
     mu4e-compose-complete-addresses t
     mu4e-compose-complete-only-personal t
     mu4e-user-mail-address-list
     (cond
      (I-am-at-work  '("alex.bennee@linaro.org"))
      (t '("alex@bennee.com")))
     mu4e-compose-complete-only-after "2013-11-01"
     ;; view options
     mu4e-view-show-images t
     mu4e-view-show-addresses t
     mu4e-view-fill-headers nil
     mu4e-html2text-command "html2text -utf8 -width 72"
     mu4e-view-fields
     '(:from :to :cc :subject :flags :date :tags :attachments
             :signature)
     mu4e-maildir-shortcuts
     (cond
      (I-am-at-work
       '( ("/linaro/Inbox"     . ?i)
          ("/linaro/mythreads" . ?m)
          ("/linaro/archived" . ?A)
          ("/linaro/team"      . ?t)
          ("/linaro/kernel/lkml"      . ?l)
          ("/linaro/virtualization/qemu" . ?q)
          ("/linaro/virtualization/qemu-arm" . ?a)
          ("/linaro/virtualization/qemu-multithread" . ?M)
          ("/linaro/virtualization/kvm-arm" . ?k)
          ("/sent"             . ?s) ))
      (t
       '( ("/"     . ?i)
          ("/.Spam" . ?s)
          ("/.Oldmail" . ?o) ))))

    ;; Header markers
    (defvar my-mu4e-patches nil
      "List of mu4e-messages snagged by the (Patches) actions.")
    (defvar my-mu4e-applied-patches nil
      "List of mu4e-messages successfully applied by the (Patches)
    actions.")
    (make-variable-buffer-local 'my-mu4e-patches)
    (make-variable-buffer-local 'my-mu4e-applied-patches)

    (defun my-mu4e-apply-marked-mbox-patches ()
      "Apply patches in order."
      (interactive)
      (let ((applied-or-skipped
             (--take-while
              (let ((docid (plist-get it :docid)))
                (if (mu4e-mark-docid-marked-p docid)
                    (if (= 0 (mu4e-action-git-apply-mbox it))
                        (when (mu4e~headers-goto-docid docid)
                          (mu4e-mark-set 'unmark) t)
                      ; failed to apply, stop
                      nil)
                  ; not marked, skip
                  t))
              (--sort
               (string<
                (mu4e-message-field-raw it :subject)
                (mu4e-message-field-raw other :subject))
               (-difference my-mu4e-patches
                            my-mu4e-applied-patches)))))
        (setq my-mu4e-applied-patches
              (-union my-mu4e-applied-patches applied-or-skipped))

        (message (format "Applied %d (%d)/%d patches"
                         (length applied-or-skipped)
                         (length my-mu4e-applied-patches)
                         (length my-mu4e-patches)))))

    ;; The following two functions are custom marker functions
    ;; Match function
    (defun my-mu4e-patch-match (msg parent-id)
      "Match any patches related to the parent-id. Add them
to `my-mu4e-patches' for later processing."
      (when
          (and (string-match parent-id
                             (or
                              (mu4e-message-field-raw msg :in-reply-to)
                              ""))
               (string-match
                (rx
                 (: bol "["
                    (minimal-match (zero-or-more (not (any "/"))))
                    (or (: (any "0-9") (any "1-9"))
                        (: (any "1-9") (any "0-9")))
                    "/"))
                (mu4e-message-field-raw msg :subject)))
        (add-to-list 'my-mu4e-patches msg)))


    ;; Param function
    (defun my-mu4e-patch-setup ()
      "Reset the patch list and extract parent-id for `my-mu4e-patch-match'"
      (setq my-mu4e-patches nil
            my-mu4e-applied-patches nil)
      (let ((msg (mu4e-message-at-point)))
        (mu4e-message-field-raw msg :message-id)))

    (add-to-list
     'mu4e-marks
     '(patch
       :char ("#" . "#")
       :prompt "Patch"))

    (add-to-list
     'mu4e-headers-custom-markers
     '("Patches" my-mu4e-patch-match my-mu4e-patch-setup))
    ;; Header actions
    (setq mu4e-headers-actions
          (delete-dups
           (append
            mu4e-headers-actions
            '(("gapply git patches" . mu4e-action-git-apply-patch)
              ("mgit am patch" . mu4e-action-git-apply-mbox)
              ("rrun checkpatch script" . my-mu4e-action-run-check-patch)
              ("sMark SPAM" . my-mu4e-register-spam-action)
              ("hMark HAM" . my-mu4e-register-ham-action)))))
    ;; Message actions
    (setq mu4e-view-actions
          (delete-dups
           (append
            '(("gapply git patches" . mu4e-action-git-apply-patch)
              ("mgit am patch" . mu4e-action-git-apply-mbox)
              ("crun checkpatch script" . my-mu4e-action-run-check-patch)))))
    ;; Bookmarks
    (setq mu4e-bookmarks
          (cond
           (I-am-at-work
            '(
              ;; Personal bookmarks
              ("recip:alex.bennee flag:unread "
               "Unread posts addressed to me" ?M)
              ("recip:alex.bennee flag:list flag:unread "
               "Unread list email addressed to me" ?m)
              ("recip:alex.bennee AND \( \(reviewed ADJ by\) OR \(signed ADJ off ADJ by\) \)"
               "Mail addressed to me with git tags" ?g)
              ("\(from:alex.bennee OR from:bennee.com\)"
               "Mail sent by me" ?s)
              ("recip:alex.bennee s:Re NOT flag:seen"
               "Mail sent by me (unread replied)" ?S)
              ("\(from:alex.bennee OR from:bennee.com\) AND s:PATCH NOT s:Re"
               "My patches" ?p)
              ("s:PULL \(b:Bennée OR b:Bennee\)" "Pull Reqs with my name" ?P)
              ("flag:flagged" "Flagged and starred posts" ?f)
              ("flag:flagged NOT flag:seen" "Unread flagged and starred posts" ?F)
              ("to:alex.bennee@linaro.org AND from:christoffer.dall@linaro.org"
               "From my boss" ?B)
              ("date:1h..now"
               "In the last hour" ?h)
              ("date:1h..now AND flag:unread"
               "In the last hour (unread)" ?H)
              ;; Virt related
              ("list:qemu-devel.nongnu.org and flag:unread"
               "Latest QEMU posts" ?q)
              ("((list:qemu-devel.nongnu.org AND (s:aarch64 OR s:arm OR s:A64)) OR list:qemu-arm.nongnu.org)"
               "QEMU ARM posts" ?a)
              ("list:mttcg.listserver.greensocs.com OR maildir:/linaro/virtualization/qemu-multithread"
               "Multi-threaded QEMU posts" ?T)
              ("list:android-emulator-dev.googlegroups.com OR (list:qemu-devel.nongnu.org AND subject:android)"
               "Android related emails" ?A)
              ("list:kvmarm.lists.cs.columbia.edu and flag:unread"
               "Latest ARM KVM posts" ?k)
              ("list:virtualization.linaro.org and flag:unread"
               "Linaro Virtualization List" ?v)
              ("maildir:\"/linaro/virtualization/*\" AND flag:list AND flag:unread"
               "All unread Virtualization email" ?V)
              ;; Linaro Specific
              ("list:conf.lists.linaro.org AND flag:unread"
               "Latest Conf emails" ?c)
              ("list:linaro-dev.lists.linaro.org AND flag:unread"
               "Latest Linaro-Dev emails" ?d)
              ("list:tech.lists.linaro.org AND flag:unread"
               "Latest Linaro-Tech emails" ?t)
              ("\(to:lists.linaro.org OR cc:lists.linaro.org\) AND flag:list AND flag:unread"
               "Unread work mailing lists (lists.linaro.org)" ?l)
              ("from:linaro.org and flag:unread"
               "Latest unread Linaro posts from Linaro emails" ?L)
              ;; Emacs
              ("list:emacs-devel.gnu.org and flag:unread"
               "Latest unread Emacs developer posts" ?E)
              ("list:help-gnu-emacs.gnu.org and flag:unread"
               "Latest unread Emacs user posts" ?e)
              ("list:emacs-orgmode.gnu.org and flag:unread"
               "Latest unread org-mode posts" ?o)))
           (I-am-on-server
            '(
              ;; Personal bookmarks
              ("\(to:alex@bennee.com or cc:alex@bennee.com\) AND flag:unread "
               "Unread posts addressed to me" ?M)
              ("flag:list AND flag:unread "
               "Unread list/notification email" ?m)
              ("\(from:alex.bennee OR from:bennee.com\)"
               "Mail sent by me" ?s)
              ("from:eileen OR from:nigel"
               "From parents" ?P)
              ("to:bugzilla@bennee.com" "Bug Mail" ?B)))))))

              
(use-package helm-mu
  :commands helm-mu
  :if (and (string-match "zen" (system-name))
           (locate-library "helm-mu"))
  :config (progn
            (setq helm-mu-contacts-personal t)
            (define-key mu4e-headers-mode-map (kbd "C-s") 'helm-mu)))

;; Magic handling for multiple email addrsses
(defvar my-email-address-alist
  '( ("Maildir/developer" . "kernel-hacker@bennee.com")
     ("Maildir/linaro" . "alex.bennee@linaro.org")
     ("Maildir/personal" . "alex@bennee.com") )
  "List of mappings from Maildir->email address.")

(defun my-choose-mail-address ()
  "Pick new `user-mail-address' based on the parent email.
Sadly this is not a local variable as at the time of the
hook we are not yet in the compose buffer."
  (let ((email
         (when mu4e-compose-parent-message
           (assoc-default
            (plist-get mu4e-compose-parent-message :path)
            my-email-address-alist 'string-match))))
    (setq user-mail-address
          (if email
              email
            (cond
             (I-am-at-work "alex.bennee@linaro.org")
             (t "alex@bennee.com"))))))

;; Utility functions for email

(defun my-snip-region (beg end)
  "Kill the region BEG to END and replace with <snip> tag."
  (interactive (list (point) (mark)))
  (kill-region beg end)
  (when (string-prefix-p ">" (car kill-ring))
    (insert "<snip>\n")))

;; Reset the cache of the directory list
(defun my-reset-mu4e-caches ()
  "Reset some of mu4e's caches to avoid restarting."
  (interactive)
  (setq mu4e~maildir-list nil))

;;
;; Checkpatch in emails
;;
(defvar my-checkpatch-script-history nil
  "History of checkpatch invocations.")

(defun my-mu4e-do-checkpatch (script-path msg)
  "Run `SCRIPT-PATH' on `MSG'."
  (let ((proc-name "checkpatch")
        (buff-name (get-buffer-create (format "*checkpatch*")))
        (msg-path (mu4e-message-field msg :path)))
    ;; header
    (with-current-buffer buff-name
      (goto-char (point-max))
      (insert (format "Running %s on %s\n"
                      script-path
                      (mu4e-message-field msg :subject))))
    ;; checkpatch
    (start-process-shell-command
     proc-name
     buff-name
     (format "cat %s | %s -" msg-path script-path))
    ;;
    (switch-to-buffer buff-name)
    (goto-char (point-max))
    (compilation-minor-mode)))

(defun my-mu4e-action-run-check-patch (msg)
  "Run checkpatch against the [patch] `MSG'."
  (let ((last-script (car my-checkpatch-script-history)))
    ;; prompt the user if we can't go with the last run
    (when (not (and last-script
                    (file-exists-p last-script)
                    (s-contains? default-directory last-script)))
      (let ((ido-work-file-list my-checkpatch-script-history))
        (setf last-script
              (ido-read-file-name
               "Checkpatch Script: " default-directory))
        (setf my-checkpatch-script-history
              (cons last-script (delete last-script
                                        my-checkpatch-script-history)))))
      ;; do the checkpatch
      (my-mu4e-do-checkpatch last-script msg)))

;; WIP: Pull requests
(defun my-insert-pull-request ()
  "Insert basic pull request into buffer."
  (interactive)
  (with-current-buffer (current-buffer)
    (insert
     (shell-command-to-string
      (format
       "git request-pull %s http://github.com/stsquad/qemu.git HEAD"
       (ido-completing-read
        "Commit start:" '("HEAD~" "origin/master") 'nil))))))

(provide 'my-email)
;;; my-email.el ends here
