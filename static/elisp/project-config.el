;; project start

(defun my/project-try-local (dir)
  "Determine if DIR is a non-Git project."
  (catch 'ret
    (let ((pr-flags '((".project")
                      ("go.mod" "Cargo.toml" "build.zig" "project.clj" "deps.edn" "pom.xml" "package.json") ;; higher priority
                      ("Makefile" "Vagrantfile" "README.org" "README.md"))))
      (dolist (current-level pr-flags)
        (dolist (f current-level)
          ;; (message "d %s f %s" dir f)
          (when-let ((root (locate-dominating-file dir f)))
            (throw 'ret (cons 'local root))))))))

(setq project-find-functions '(my/project-try-local project-try-vc)
      project-switch-commands '((project-find-file "Find file" ?f)
                                (my/project-recentf "Recent files" ?r)
                                (my/project-search "Search" ?s)
                                (project-find-dir "Find directory")
                                (magit-project-status "Magit" ?m)
                                (my/project-loc "LOC" ?l)
                                (my/project-eshell "Eshell" ?e)))

(cl-defmethod project-root ((project (head local)))
  (cdr project))

(defun my/project-files-in-directory (dir)
  "Use `fd' to list files in DIR."
  (let* ((default-directory dir)
         (localdir (file-local-name (expand-file-name dir)))
         (command (format "fd -H -t f -0 . %s" localdir)))
    (project--remote-file-names
     (sort (split-string (shell-command-to-string command) "\0" t)
           #'string<))))

(cl-defmethod project-files ((project (head local)) &optional dirs)
  "Override `project-files' to use `fd' in local projects."
  (mapcan #'my/project-files-in-directory
          (or dirs (list (project-root project)))))

(defun my/project-remember-advice (fn pr &optional no-write)
  (let* ((remote? (file-remote-p (project-root pr)))
         (no-write (if remote? t no-write)))
    (funcall fn pr no-write)))

(advice-add 'project-remember-project :around
            'my/project-remember-advice)

(defun my/project-new-root ()
  (interactive)
  (let* ((root-dir (read-directory-name "Root: "))
         (f (expand-file-name ".project" root-dir)))
    (message "Create %s..." f)
    (make-empty-file f)))

(defun my/project-add (dir)
  (interactive "DDirectory: \n")
  (project-remember-project dir nil))

(defun my/project-info ()
  (interactive)
  (message "%s" (project-current t)))

(defun my/project-discover ()
  (interactive)
  (dolist (search-path '("~/code/" "~/gh/" "~/code/antfin/" "~/code/misc"))
    (dolist (file (file-name-all-completions  "" search-path))
      (when (not (member file '("./" "../")))
        (let ((full-name (expand-file-name file search-path)))
          (when (file-directory-p full-name)
            (when-let ((pr (project-current nil full-name)))
              (project-remember-project pr)
              (message "add project %s..." pr))))))))

(defun my/project-recentf ()
  (interactive)
  (let* ((pr (project-current t))
         (root-dir (expand-file-name (project-root pr)))
         (files (or (thread-last
                      recentf-list
                      (seq-filter (lambda (filename)
                                    (and (string-prefix-p root-dir filename)
                                         (if-let ((curr-name (buffer-file-name)))
                                             (not (string-equal curr-name filename))
                                           t))))
                      (mapcar 'abbreviate-file-name))
                    (project-files pr))))
    (ivy-read "Recentf: " files
              :action 'find-file)))

(defun my/makefile-targets (dir)
  "Find Makefile targets in dir. https://stackoverflow.com/a/58316463/2163429"
  (let* ((default-directory dir))
	(with-temp-buffer
	  (insert (shell-command-to-string "make -qp"))
	  (goto-char (point-min))
	  (let ((targets '()))
		(while (re-search-forward "^\\([a-zA-Z0-9][^$#\\/\\t=]*\\):[^=|$]" nil t)
		  (let ((target (match-string 1)))
			(unless (member target '("Makefile" "make" "makefile" "GNUmakefile"))
			  (push target targets))))
		(sort targets 'string-lessp)))))

(defun my/project-run-makefile-target ()
  (interactive)
  (let* ((pr (project-current t))
		 (default-directory (project-root pr))
		 (target (completing-read "Target: " (my/makefile-targets default-directory)))
         (buf-name "*Async Makefile Target*"))
    (when-let (b (get-buffer buf-name))
      (kill-buffer b))
	(async-shell-command (concat "make " (shell-quote-argument target)) buf-name)))

(defun my/project-loc ()
  (interactive)
  (let* ((pr (project-current t))
		 (default-directory (project-root pr))
         (buf (get-buffer-create (format "*%s LOC*" (cdr pr))))
         (inhibit-read-only t))
    (with-current-buffer buf
      (erase-buffer)
	  (async-shell-command "loc" buf buf)
      (evil-normal-state))
    (switch-to-buffer-other-window buf)))

(defun my/project-eshell ()
  "Start project eshell in other window.
https://emacs.stackexchange.com/a/13581/16450"
  (interactive)
  (let ((buf (project-eshell)))
    (switch-to-buffer (other-buffer buf))
    (switch-to-buffer-other-window buf)))

(defun my/project-eshell-bottom ()
  (interactive)
  (let* ((buf-name (project-prefixed-buffer-name "eshell")))
    (if-let ((win (get-buffer-window buf-name)))
        (delete-window win)
      (my/split-window-below)
      (project-eshell)
      (ignore-errors
        (shrink-window 10)))))

(defun my/project-citre ()
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (citre-create-tags-file)
    (add-dir-local-variable 'prog-mode 'eval '(citre-mode))))

(defun my/project-search ()
  (interactive)
  (let* ((default-directory (project-root (project-current t)))
         (is-git (vc-git-responsible-p default-directory)))
    (ivy-read (format "%s Search: " (if is-git "Git" "Rg")) nil
              :action (lambda (word)
                        (if is-git
                            (counsel-git-grep word default-directory)
                          (counsel-rg word default-directory))))))

;; project end
