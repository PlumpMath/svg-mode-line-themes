(require 'cl)
(or (require 'xmlgen nil t)
    (require 'xmlgen "xml-gen"))

(defvar smt/current-theme nil)

(defmacro smt/deftree (name &rest props)
  (declare (indent 1))
  (let (( maker-name
          (intern (concat "smt/make-"
                          (symbol-name name))))
        ( \definer-name
          (intern (concat "smt/def" (symbol-name name))))
        ( namespace-name
          (intern (concat "smt/" (symbol-name name) "s")))
        ( predicate-name
          (intern (concat "smt/" (symbol-name name) "-p")))
        ( get-name (intern (concat "smt/"
                                   (substring (symbol-name name)
                                              0 1)
                                   "-get"))))
    `(progn
       (defvar ,namespace-name nil)
       (defun ,maker-name (&rest pairs)
         (unless (memq :parent pairs)
           (setf (getf pairs :parent) 'archetype))
         pairs)
       (defmacro ,definer-name (name &rest pairs)
         (declare (indent 1))
         `(let* (( object (,',maker-name ,@pairs)))
            (setq ,',namespace-name (cl-delete ',name ,',namespace-name :key 'car)
                  ,',namespace-name (acons ',name object ,',namespace-name))
            object))
       (put (quote ,definer-name) 'common-lisp-indent-function
            '(1 &body))
       (,definer-name archetype
           ,@(append (list :parent nil :type (list 'quote name))
                     props))
       (defun ,get-name (object property)
         (smt/get object property ,namespace-name))
       (defun ,predicate-name (object)
         (and (consp object)
              (eq ',name (smt/get object :type ,namespace-name))))
       )))
(put 'smt/deftree 'common-lisp-indent-function
     '(1 &body))

(defun smt/get (object property &optional namespace)
  (cond ( (memq property object)
          (getf object property))
        ( (getf object :parent)
          (let* (( parent (getf object :parent)))
            (when (symbolp parent)
              (setq parent (cdr (assoc parent namespace))))
            (smt/get parent property namespace)))))

(defun smt/maybe-funcall (thing &rest args)
  (if (or (functionp thing)
          (and (symbolp thing)
               (fboundp thing)))
      (apply thing args)
      thing))

;;; Theme

(smt/deftree theme
  :background nil
  :overlay nil
  :defs nil
  :export-func 'smt/t-export-default
  :style 'smt/default-base-style
  :local-widgets nil
  :rows nil)

(defun smt/t-background (theme)
  (smt/maybe-funcall (smt/t-get theme :background)))

(defun smt/t-overlay (theme)
  (smt/maybe-funcall (smt/t-get theme :overlay)))

(defun smt/t-defs (theme)
  (smt/maybe-funcall (smt/t-get theme :defs)))

(defun smt/t-export (theme)
  (smt/maybe-funcall (smt/t-get theme :export-func) theme))

(defun smt/t-style (theme)
  (smt/maybe-funcall (smt/t-get theme :style)))

(defun smt/t-local-widgets (theme)
  (smt/maybe-funcall (smt/t-get theme :local-widgets)))

(defun smt/t-rows (theme)
  (smt/maybe-funcall (smt/t-get theme :rows)))

;;; Row

(smt/deftree row
  :align 'left
  :width-func 'smt/r-width-default
  :margin 0
  :widgets nil
  :style nil
  :export-func 'smt/r-export-default)

(defun smt/make-row (&rest pairs)
  (unless (memq :parent pairs)
    (setf (getf pairs :parent) 'archetype))
  (when (eq (getf pairs :align) 'center)
    (setf (getf pairs :align) 'left)
    (setf (getf pairs :margin)
          (lambda (row)
            (floor
             (/ (- (smt/window-width)
                   (smt/r-width row))
                2)))))
  pairs)

(defun smt/r-align (row)
  (smt/maybe-funcall (smt/r-get row :align)))

(defun smt/r-width (row)
  (smt/maybe-funcall (smt/r-get row :width-func) row))

(defun smt/r-margin (row)
  (smt/maybe-funcall (smt/r-get row :margin) row))

(defun smt/r-widgets (row)
  (smt/maybe-funcall (smt/r-get row :widgets)))

(defun smt/r-style (row)
  (smt/maybe-funcall (smt/r-get row :style)))

(defun smt/r-export (row theme)
  (smt/maybe-funcall
   (smt/r-get row :export-func)
   row theme))

;;; Widget

(smt/deftree widget
  :style 'smt/default-base-style
  :on-click nil
  :text ""
  :width-func 'smt/w-width-default
  :export-func 'smt/w-export-default)

(defun smt/w-style (widget)
  (smt/maybe-funcall (smt/w-get widget :style)))

(defun smt/w-text (widget)
  (smt/maybe-funcall (smt/w-get widget :text)))

(defun smt/w-width (widget)
  (smt/maybe-funcall
   (smt/w-get widget :width-func)
   widget))

(defun smt/w-export (widget row theme)
  (smt/maybe-funcall
   (smt/w-get widget :export-func)
   widget row theme))

(defun smt/w-on-click (widget)
  (smt/w-get widget :on-click))

;;; Structs EOF
;;; Methods

(defun smt/ranges-overlap (r1 r2)
  (cond ( (<= (cdr r1) (car r2))
          nil)
        ( (<= (cdr r2) (car r1))
          nil)
        ( t t)))

(defun smt/r-range (row)
  (let (( left (smt/r-left row)))
    (cons left (+ left (smt/r-width row)))))

(defun smt/t-visible-rows (theme)
  (let* (( rows (mapcar (apply-partially 'smt/t-normalize-row theme)
                        (smt/t-rows theme))))
    (dotimes (iter (length rows))
      (when (nth iter rows)
        (let* (( current-row (nth iter rows))
               ( following-rows (nthcdr (1+ iter) rows))
               ( current-row-range
                 (smt/r-range current-row)))
          (dotimes (iter2 (length following-rows))
            (when (nth iter2 following-rows)
              (let (( following-row-range
                      (smt/r-range (nth iter2 following-rows))))
                (when (or (smt/ranges-overlap
                           current-row-range
                           following-row-range)
                          (minusp (car following-row-range)))
                  (setf (nth iter2 following-rows) nil))))))))
    (remove-if 'null rows)))

(defun smt/t-export-default-xml (theme)
  (let* (( width (smt/window-pixel-width))
         ( height (frame-char-height))
         ( rows (smt/t-visible-rows theme)))
    (xmlgen
     `(svg
       :xmlns "http://www.w3.org/2000/svg"
       :width ,width
       :height ,height
       ,@(smt/t-defs theme)
       ,@(smt/t-background theme)
       ,@(mapcar
          (lambda (row) (smt/r-export row theme))
          rows)
       ,@(smt/t-overlay theme)
       ))))

(defun* smt/define-keys (keymap &rest bindings)
  "Syntax example:
\(smt/define-keys fundamental-mode-map
  (kbd \"h\") 'backward-char
  (kbd \"l\") 'forward-char\)
 Returns the keymap in the end."
  (while bindings
    (define-key keymap (pop bindings) (pop bindings)))
  keymap)
(put 'smt/define-keys 'common-lisp-indent-function
     '(4 &body))

(defun* smt/t-export-default (theme)
  ;; (return-from smt/t-export-default)
  (let* ((xml (smt/t-export-default-xml theme))
         (image (create-image xml 'svg t)))
    (propertize
     "."
     'display image
     'keymap (let (( map (make-sparse-keymap)))
               (smt/define-keys
                   map
                 (kbd "<mouse-1>") 'smt/receive-click
                 (kbd "<nil> <header-line> <mouse-1>") 'smt/receive-click
                 (kbd "<nil> <mode-line> <mouse-1>") 'smt/receive-click
                 (kbd "<header-line> <mouse-1>") 'smt/receive-click
                 (kbd "<mode-line> <mouse-1>") 'smt/receive-click)
               map))))

(defun smt/r-width-default (row)
  (let (( widgets (smt/r-widgets row))
        ( total-width 0))
    (dolist (widget widgets)
      (setq widget
            (smt/t-normalize-widget
             (smt/get-current-theme)
             widget))
      (incf total-width (smt/w-width widget)))
    total-width))

(defun smt/t-normalize-widget (theme widget-or-name)
  (if (smt/widget-p widget-or-name)
      widget-or-name
      (or (cdr (assoc widget-or-name (smt/t-local-widgets theme)))
          (cdr (assoc widget-or-name smt/widgets))
          (error "Can't process widget: %s" widget-or-name))))

(defun smt/t-normalize-row (theme row-or-name)
  (if (smt/row-p row-or-name)
      row-or-name
      (or (cdr (assoc row-or-name smt/rows))
          (error "Can't process row: %s" row-or-name))))

(defun smt/r-export-default (row theme)
  `(text
    :text-anchor ,(progn
                   (case (smt/r-align row)
                     ( left "start")
                     ( right "end")))
    :x ,(progn
         (case ( smt/r-align row)
           ( left (* (smt/r-margin row)
                     (frame-char-width)))
           ( right (- (smt/window-pixel-width)
                      (* (smt/r-margin row)
                         (frame-char-width))))))
    :y ,(smt/text-base-line)
    ,@(mapcar (lambda (widget-or-name)
                (smt/w-export
                 (smt/t-normalize-widget
                  theme widget-or-name)
                 row theme))
              (smt/r-widgets row))))

(defun smt/w-export-default (widget row theme)
  `(tspan
    ,@(smt/+ (smt/t-style theme)
             (smt/r-style row)
             (smt/w-style widget))
    ,(smt/w-text widget)))

(defun smt/w-width-default (widget)
  (length (smt/w-text widget)))

(defun* smt/r-receive-click (row theme event)
  (setq row (smt/t-normalize-row theme row))
  (let* (( click-char-location
           (floor (/ (car (third (second event)))
                     (frame-char-width))))
         ( window-width (smt/window-width))
         ( widgets (smt/r-widgets row))
         ( offset (smt/r-left row))
         current-widget-width)
    (dolist (widget widgets)
      (setq widget (smt/t-normalize-widget theme widget))
      (setq current-widget-width (smt/w-width widget))
      (when (and (<= offset click-char-location)
                 (< click-char-location
                    (+ offset current-widget-width)))
        (when (smt/w-on-click widget)
          (funcall (smt/w-on-click widget) event)
          (return-from smt/r-receive-click t))
        (error "Widget has no on-click handler"))
      (setq offset (+ offset current-widget-width)))
    nil))

(defun* smt/t-receive-click (theme event)
  (let (( rows (smt/t-visible-rows theme)))
    (ignore-errors
      (dolist (row rows)
        (setq row (smt/t-normalize-row theme row))
        (when (smt/r-receive-click row theme event)
          (return-from smt/t-receive-click))))
    (message "")))

(defun smt/receive-click (event)
  (interactive "e")
  (smt/t-receive-click
   (smt/get-current-theme)
   event))

(defun smt/r-left (row)
  (let (( margin (smt/r-margin row))
        ( width (smt/r-width row)))
    (if (eq 'left (smt/r-align row))
        margin
        (- (smt/window-width) (+ margin width)))))

;;; Methods EOF

(defun smt/window-pixel-width ()
  (let (( window-edges (window-pixel-edges)))
    (- (nth 2 window-edges) (nth 0 window-edges))))

(defun smt/window-width ()
  (let (( window-edges (window-edges)))
    (- (nth 2 window-edges) (nth 0 window-edges))))

(defun smt/copy-struct (struct)
  (funcall
   (intern
    (concat
     "copy-"
     (substring
      (symbol-name
       (aref 0 struct))
      10)))
   struct))

(defun smt/points-to-pixels (points)
  ;; points = pixels * 72 / 96
  (/ (* 96 points) 72))

(defun smt/font-pixel-size ()
  (ceiling
   (smt/points-to-pixels
    (/ (face-attribute 'default :height) 10))))

(defun smt/text-base-line ()
  ;; Should be this one, but empirically it doesn't work as well
  ;; (smt/font-pixel-size)
  (let ((font-size (* 0.7 (smt/font-pixel-size))))
    (floor
     (+ font-size
        (/ (- (frame-char-height)
              font-size)
           2)))))

(defun smt/default-base-style ()
  `(:font-family
    ,(face-attribute 'default :family)
    :font-size
    ,(concat (int-to-string
              (round
               (/ (face-attribute 'default :height)
                  10.0)))
             "pt")))

(defun* smt/filter-inset (&optional (dark-opacity 0.5) (light-opacity 0.5))
  `((filter
     :id "inset"
     (feOffset :in "sourceGraphic" :dx -1 :dy -1 :result "o_dark")
     (feOffset :in "sourceGraphic" :dx 2 :dy 2 :result "o_light")
     ;; http://www.w3.org/TR/SVG/filters.html#feColorMatrixElement
     ;; http://en.wikipedia.org/wiki/Matrix_multiplication#Illustration
     (feColorMatrix
      :type "matrix"
      :in "o_light" :result "o_light"
      :values ,(concat
                "0  0  0  0  1 "
                "0  0  0  0  1 "
                "0  0  0  0  1 "
                (format
                 "0  0  0  %s  0 "
                 light-opacity)
                ))
     (feColorMatrix
      :type "matrix"
      :in "o_dark" :result "o_dark"
      :values ,(concat
                "0  0  0  0  -1 "
                "0  0  0  0  -1 "
                "0  0  0  0  -1 "
                (format
                 "0  0  0  %s  0 "
                 dark-opacity)
                ))
     (feMerge
      (feMergeNode :in "o_dark")
      (feMergeNode :in "o_light")
      (feMergeNode :in "SourceGraphic")
      ))))

(defun smt/+ (&rest plists)
  (cond
    ( (= 1 (length plists))
      (car plists))
    ( (null plists)
      nil)
    ( t (let (( plistC (copy-list (car plists)))
              ( plistB (cadr plists))
              key val)
          (dotimes (iter (/ (length plistB) 2))
            (setq key (nth (* 2 iter) plistB)
                  val (nth (1+ (* 2 iter)) plistB))
            (if (null val)
                (remf plistC key)
                (setf (getf plistC key) val)))
          (apply 'smt/+ plistC (cddr plists))
          ))))

(defun smt/modeline-format ()
  (let ((theme (smt/get-current-theme)))
    (cond ( (smt/theme-p theme)
            (smt/t-export theme))
          ( (or (functionp theme)
                (symbolp theme))
            (funcall theme))
          ( t theme))))

(defun smt/get-current-theme ()
  (cdr (assoc smt/current-theme smt/themes)))

(defun smt/get-widget-by-name (name)
  (cdr (assoc name smt/widgets)))

(defun smt/reset ()
  (interactive)
  (let (( tests-where-loaded
          (featurep 'svg-mode-line-themes-tests)))
    (ignore-errors
      (unload-feature 'svg-mode-line-themes t))
    (ignore-errors
      (unload-feature 'svg-mode-line-themes-widgets t))
    (ignore-errors
      (unload-feature 'svg-mode-line-themes-core t))
    (ignore-errors
      (unload-feature 'svg-mode-line-themes-nasa t))
    (ignore-errors
      (unload-feature 'svg-mode-line-themes-black-crystal t))
    (ignore-errors
      (unload-feature 'svg-mode-line-themes-diesel t))
    (require (quote svg-mode-line-themes))
    (when tests-where-loaded
      (ignore-errors
        (unload-feature 'svg-mode-line-themes-tests t))
      (require (quote svg-mode-line-themes-tests)))))

(provide 'svg-mode-line-themes-core)
;; svg-mode-line-themes-core.el ends here
