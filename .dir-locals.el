;;; Directory Local Variables
;;; For more information see (info "(emacs) Directory Variables")

((org-mode . ((org-babel-default-header-args:bash . ((:dir . "/tmp")))
              (time-stamp-start . "#\\+LASTMOD:[ \t]*")
              (time-stamp-end . "$")
              (time-stamp-format . "%Y-%m-%dT%02H:%02M:%02S%5z")
              (eval . (add-hook 'before-save-hook 'time-stamp nil t)))))
