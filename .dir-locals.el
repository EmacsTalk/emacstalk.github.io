;;; Directory Local Variables
;;; For more information see (info "(emacs) Directory Variables")

((org-mode . ((org-babel-default-header-args:bash . ((:dir . "/tmp")))
              (eval . (add-hook 'before-save-hook 'time-stamp nil t)))))
