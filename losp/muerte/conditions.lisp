;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 2001-2004, 
;;;;    Department of Computer Science, University of Troms�, Norway.
;;;; 
;;;;    For distribution policy, see the accompanying file COPYING.
;;;; 
;;;; Filename:      conditions.lisp
;;;; Description:   
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Wed Nov 20 15:47:04 2002
;;;;                
;;;; $Id: conditions.lisp,v 1.1 2004/01/13 11:05:05 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(require :muerte/basic-macros)
(provide :muerte/conditions)

(in-package muerte)

(defvar *active-condition-handlers* nil)
(defparameter *break-on-signals* nil)

(defparameter *debugger-function* nil)
(defvar *debugger-dynamic-context* nil)
(defparameter *debugger-invoked-stack-frame* nil)
(defvar *debugger-condition*)

(defmacro define-condition (name parent-types slot-specs &rest options)
  `(progn
     (defclass ,name ,(or parent-types '(condition)) ,slot-specs)
     ,@(let ((reporter (cadr (assoc :report options))))
	 (when reporter
	   `((defmethod print-object ((condition ,name) stream)
	       (if *print-escape*
		   (call-next-method)
		 (funcall (function ,reporter) condition stream))
	       condition))))
     ',name))

#+ignore
(defmethod print-object ((c condition) s)
  foo)

(define-condition condition (standard-object)
  ((format-control
    :initarg :format-control
    :initform nil
    :reader condition-format-control)
   (format-arguments
    :initarg :format-arguments
    :initform nil
    :reader condition-format-arguments))
  (:report (lambda (condition stream)
	     (if (or *print-escape*
		     (not (condition-format-control condition)))
		 (call-next-method)
	       (apply #'format stream
		      (condition-format-control condition)
		      (condition-format-arguments condition))))))

(define-condition simple-condition (condition) ())
(define-condition serious-condition () ())
(define-condition error (serious-condition) ())
(define-condition warning () ())
(define-condition simple-error (simple-condition error) ())
(define-condition simple-warning (simple-condition warning) ())

(define-condition cell-error (error)
  ((name
    :initarg :name
    :reader cell-error-name))
  (:report (lambda (c s)
	     (format s "Error accessing cell ~S."
		     (cell-error-name c)))))

(define-condition undefined-function (cell-error)
  ()
  (:report (lambda (c s)
	     (format s "Undefined function ~S."
		     (cell-error-name c)))))
		  
(define-condition unbound-variable (cell-error)
  ()
  (:report (lambda (c s)
	     (format s "Unbound variable ~S."
		     (cell-error-name c)))))

(define-condition program-error (error) ())

(define-condition type-error (error)
  ((expected-type
    :initarg :expected-type
    :reader type-error-expected-type)
   (datum
    :initarg :datum
    :reader type-error-datum)))

(define-condition control-error (error) ())

(define-condition throw-error (control-error)
  ((tag
    :initarg :tag
    :reader throw-error-tag))
  (:report (lambda (c s)
	     (format s "Cannot throw to tag ~Z." (throw-error-tag c)))))

(define-condition wrong-argument-count (program-error)
  ((function
    :initarg :function
    :reader condition-function)
   (argument-count
    :initarg :argument-count
    :reader condition-argument-count))
  (:report (lambda (c s)
	     (format s "Function ~S ~:A received ~D arguments."
		     (funobj-name (condition-function c))
		     (funobj-lambda-list (condition-function c))
		     (condition-argument-count c)))))

(define-condition stream-error (error)
  ((stream
    :initarg :stream
    :reader stream-error-stream)))

(define-condition end-of-file (stream-error)
  ()
  (:report (lambda (c s)
	     (format s "End of file encountered on ~W."
		     (stream-error-stream c)))))
		  
(defun make-condition (type &rest slot-initializations)
  (declare (dynamic-extent slot-initializations))
  (apply 'make-instance type slot-initializations))

(defmacro handler-bind (bindings &body forms)
  (if (null bindings)
      `(progn ,@forms)
    (labels ((make-handler (binding)
	       (destructuring-bind (type handler)
		   binding
		 (cond
		  #+ignore
		  ((and (listp handler)
			(eq 'lambda (first handler))
			(= 1 (length (second handler))))
		   `(cons t (lambda (x)
			      (when (typep x ',type)
				(let ((,(first (second handler)) x))
				  ,@(cddr handler)))
			      nil)))
		  #+ignore
		  ((and (listp handler)
			(eq 'function (first handler))
			(listp (second handler))
			(eq 'lambda (first (second handler)))
			(= 1 (length (second (second handler)))))
		   (make-handler (list type (second handler))))
		  (t `(cons ',type ,handler))))))
      `(let ((*active-condition-handlers*
	      (cons (list ,@(mapcar #'make-handler #+ignore (lambda (binding)
							      `(cons ',(first binding)
								     ,(second binding)))
				    bindings))
		    *active-condition-handlers*)))
	 ,@forms))))

(defmacro handler-case (expression &rest clauses)
  (multiple-value-bind (normal-clauses no-error-clauses)
      (loop for clause in clauses
	  if (eq :no-error (car clause))
	  collect clause into no-error-clauses
	  else collect clause into normal-clauses
	  finally (return (values normal-clauses no-error-clauses)))
    (case (length no-error-clauses)
      (0 (let ((block-name (gensym "handler-case-block-"))
	       (var-name (gensym "handler-case-var-"))
	       (temp-name (gensym "handler-case-temp-var-"))
	       (specs (mapcar (lambda (clause)
				(list clause (gensym "handler-case-clause-tag-")))
			      normal-clauses)))
	   `(block ,block-name
	      (let (,var-name)
		(tagbody
		  (handler-bind ,(mapcar (lambda (clause-spec)
					   (let* ((clause (first clause-spec))
						  (go-tag (second clause-spec))
						  (typespec (first clause)))
					     `(,typespec (lambda (,temp-name)
							   (setq ,var-name ,temp-name)
							   (go ,go-tag)))))
				  specs)
		    (return-from ,block-name ,expression))
		  ,@(mapcan (lambda (clause-spec)
			      (let* ((clause (first clause-spec))
				     (go-tag (second clause-spec))
				     (var (first (second clause)))
				     (body (cddr clause)))
				(if (not var)
				    `(,go-tag (return-from ,block-name
						(let () ,@body)))
				  `(,go-tag (return-from ,block-name
					      (let ((,var ,var-name))
						,@body))))))
			    specs))))))
      (t (error "Too many no-error clauses.")))))

(defmacro ignore-errors (&body body)
  `(handler-case (progn ,@body)
     (error (c) (values nil c))))

(defun warn (datum &rest arguments)
  (declare (dynamic-extent arguments))
  (cond
   ((not (eq t (get 'clos-bootstrap 'have-bootstrapped)))
    (fresh-line)
    (write-string "Warning: ")
    (apply 'format t datum arguments)
    (fresh-line))
   (t (with-simple-restart (muffle-warning "Muffle warning.")
	(let ((c (signal-simple 'simple-warning datum arguments))
	      (*standard-output* *error-output*))
	  (typecase datum
	    (string
	     (fresh-line)
	     (write-string "Warning: ")
	     (apply 'format t datum arguments)
	     (terpri))
	    (t (format t "~&Warning: ~A"
		       (or c (coerce-to-condition 'simple-warning datum arguments)))))))))
  nil)

(defun coerce-to-condition (default-type datum args)
  ;; (declare (dynamic-extent args))
  (etypecase datum
    (condition
     datum)
    (symbol
     (apply 'make-condition datum args))
    (string
     (make-condition default-type
       :format-control datum
       :format-arguments (copy-list args)))))

(defun signal-simple (default-type datum args)
  "Signal the condition denoted by a condition designator.
Will only make-instance a condition when it is required.
Return the condition object, if there was one."
  (declare (dynamic-extent arguments))
  (let* ((class (etypecase datum
		  (symbol
		   (find-class datum))
		  (string
		   (find-class default-type))
		  (condition
		   (class-of datum))))
	 (cpl (class-precedence-list class))
	 (condition nil)
	 (bos-type *break-on-signals*))
    (when (typecase bos-type
	    (null nil)
	    (symbol
	     (let ((bos-class (find-class bos-type nil)))
	       (if (not bos-class)
		   (typep (class-prototype-value class) bos-type)
		 (member bos-class cpl))))
	    (list
	     (typep (class-prototype-value class) bos-type))
	    (t (member bos-type cpl)))
      (break "Signalling ~S" datum))
    (macrolet ((invoke-handler (handler)
		 `(funcall ,handler
			   (or condition
			       (setf condition
				 (coerce-to-condition default-type datum args))))))
      (let ((*active-condition-handlers* *active-condition-handlers*))
	(do () ((null *active-condition-handlers*))
	  (let ((handlers (pop *active-condition-handlers*)))
	    (dolist (handler handlers)
	      (let ((handler-type (car handler)))
		(typecase handler-type
		  (symbol
		   (let ((handler-class (find-class handler-type nil)))
		     (when (if (not handler-class)
			       (typep (class-prototype-value class) handler-type)
			     (progn
			       (setf (car handler) handler-class) ; XXX memoize this find-class..
			       (member handler-class cpl)))
		       (invoke-handler (cdr handler)))))
		  (cons
		   (when (typep (class-prototype-value class) handler-type)
		     (invoke-handler (cdr handler))))
		  (null)
		  (t (when (member handler-type cpl)
		       (invoke-handler (cdr handler)))))))))))
    (or condition
	(when (typep datum condition)
	  datum))))

(defun signal (datum &rest args)
  (declare (dynamic-extent args))
  (signal-simple 'simple-condition datum args)
  nil)

(defun invoke-debugger (condition)
  (when *debugger-hook*
    (let ((hook *debugger-hook*)
	  (*debugger-hook* nil))
      (funcall hook condition hook)))
  #+ignore
  (unless *debugger-function*
    (setf *debugger-function* #'muerte.init::my-debugger))
  (cond
   ((not *debugger-function*)
    (format t "~&No debugger in *debugger-function*. Trying to abort.")
    (invoke-restart (or (find-restart 'abort)
			(format t "~%Condition for debugger: ~Z" condition)
			(format t "~%No abort restart is active. Halting CPU.")
			(halt-cpu))))
   (t (let ((*debugger-invoked-stack-frame* (stack-frame-uplink (current-stack-frame))))
	(funcall *debugger-function* condition))))
  (format *debug-io* "~&Debugger ~@[on ~S ]returned!~%Trying to abort...~%" condition)
  (let ((r (find-restart 'abort)))
    (when r
      (invoke-restart r))
    (format *debug-io* "~&Aborting failed. Halting CPU.")
    (halt-cpu)))

(defun invoke-debugger-on-designator (&rest designator)
  (declare (dynamic-extent designator))
  (if (or (eq 'break (car designator))
	  (and *error-no-condition-for-debugger*
	       (symbolp (car designator)))
	  ;; don't let an error trigger CLOS bootstrapping.
	  (not (eq t (get 'clos-bootstrap 'have-bootstrapped))))
      (invoke-debugger designator)
    (invoke-debugger (coerce-to-condition (car designator)
					  (cadr designator)
					  (cddr designator)))))

(defun break (&optional format-control &rest format-arguments)
  (declare (dynamic-extent format-arguments))
  (with-simple-restart (continue "Return from break~:[.~;~:*: ~?~]" format-control format-arguments)
    ;; (format *debug-io* "~&Break: ~?" format-control format-arguments)
    (let ((*debugger-hook* nil))
      (apply 'invoke-debugger-on-designator
	     'break
	     (or format-control "Break was invoked.")
	     format-arguments)))
  nil)