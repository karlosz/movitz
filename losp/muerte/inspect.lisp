;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 2001, 2003-2004, 
;;;;    Department of Computer Science, University of Troms�, Norway.
;;;; 
;;;;    For distribution policy, see the accompanying file COPYING.
;;;; 
;;;; Filename:      inspect.lisp
;;;; Description:   
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Fri Oct 24 09:50:41 2003
;;;;                
;;;; $Id: inspect.lisp,v 1.1 2004/01/13 11:05:05 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(require :muerte/basic-macros)
(provide :muerte/inspect)

(in-package muerte)

(define-compiler-macro check-stack-limit ()
  `(with-inline-assembly (:returns :nothing)
     (:locally (:bound (:edi (:edi-offset stack-bottom)) :esp))))

(defun check-stack-limit ()
  (check-stack-limit))

(defun stack-top ()
  (declare (without-check-stack-limit))
  (load-global-constant stack-top :thread-local t))

(defun stack-bottom ()
  (declare (without-check-stack-limit))
  (load-global-constant stack-bottom :thread-local t))

(defun (setf stack-top) (value)
  (declare (without-check-stack-limit))
  (check-type value fixnum)
  (with-inline-assembly (:returns :eax)
    (:compile-form (:result-mode :eax) value)
    ((:fs-override) :movl :eax (:edi #.(movitz::global-constant-offset 'stack-top)))))


(defun (setf stack-bottom) (value)
  (declare (without-check-stack-limit))
  (check-type value fixnum)
  (with-inline-assembly (:returns :eax)
    (:compile-form (:result-mode :eax) value)
    ((:fs-override) :movl :eax (:edi #.(movitz::global-constant-offset 'stack-bottom)))))


(defun stack-frame-uplink (stack-frame)
  (values (truncate (stack-ref (* 4 stack-frame) 0 0 :unsigned-byte32)
		    4)))

(define-compiler-macro current-stack-frame ()
  `(with-inline-assembly (:returns :eax)
     (:leal ((:ebp ,(truncate movitz::+movitz-fixnum-factor+ 4)))
	    :eax)))

(defun current-stack-frame ()
  (stack-frame-uplink (current-stack-frame)))

(defun stack-frame-funobj (stack-frame &optional accept-non-funobjs)
  (when stack-frame
    (let ((x (stack-frame-ref stack-frame -1)))
      (and (or accept-non-funobjs
	       (typep x 'function))
	   x))))

(defun stack-frame-call-site (stack-frame)
  "Return the code-vector and offset into this vector that is immediately
after the point that called this stack-frame."
  (let ((funobj (stack-frame-funobj (stack-frame-uplink stack-frame))))
    (when funobj
      (let* ((code-vector (funobj-code-vector funobj))
	     (x (stack-ref (* 4 stack-frame) 0 1 :unsigned-byte32))
	     (delta (- x 8 (* #.movitz::+movitz-fixnum-factor+ (object-location code-vector)))))
	(when (below delta (length code-vector))
	  (values delta code-vector funobj))))))

(defun stack-frame-ref (stack-frame index)
  (if (= 0 index)
      (stack-frame-uplink stack-frame)
    (stack-ref (* 4 stack-frame) 0 index :lisp)))

(defun stack-ref-p (pointer)
  (let ((top (load-global-constant-u32 stack-top))
	(bottom (with-inline-assembly (:returns :untagged-fixnum-ecx)
		  (:movl :esp :ecx))))
    (<= bottom pointer top)))

(defun stack-ref (pointer offset index type)
  (assert (stack-ref-p pointer) (pointer)
    "Stack pointer not in range: #x~X" pointer)
  (memref-int pointer offset index type))

(defun current-dynamic-context ()
  (with-inline-assembly (:returns :untagged-fixnum-ecx)
    (:locally (:movl (:edi (:edi-offset dynamic-env)) :ecx))))

(defun dynamic-context-uplink (dynamic-context)
  (stack-ref dynamic-context 12 0 :unsigned-byte32))

(defun dynamic-context-tag (dynamic-context)
  (stack-ref dynamic-context 4 0 :lisp))

(defmacro with-each-dynamic-context ((&optional start-context result) &rest clauses)
  "Only use this if you know what you're doing. See run-time.lisp."
  (let ((context (gensym "dynamic-context-"))
	(tag (gensym "dynamic-tag-"))
	(bind-clause (find :binding clauses :key #'caar))
	(catch-clause (find :catch clauses :key #'caar))
	(up-clause (find :unwind-protect clauses :key #'caar))
	(basic-restart-clause (find :basic-restart clauses :key #'caar)))
    `(do ((,context ,(if start-context start-context '(current-dynamic-context))
		    (dynamic-context-uplink ,context)))
	 ((not (stack-ref-p ,context)) ,result)
       (let ((,tag (dynamic-context-tag ,context)))
	 (cond
	  ,@(when bind-clause
	      `(((eq ,tag (load-global-constant unbound-value))
		 (multiple-value-bind ,(cdar bind-clause)
		     (values ,context
			     (stack-ref ,context 0 0 :lisp)
			     (stack-ref ,context 8 0 :lisp))
		   ,@(rest bind-clause)))))
	  ,@(when up-clause
	      `(((eq ,tag (load-global-constant unwind-protect-tag))
		 (multiple-value-bind ,(cdar up-clause)
		     (values ,context)
		   ,@(rest up-clause)))))
	  ,@(when basic-restart-clause
	      `(((eq ,tag (load-global-constant restart-tag))
		 (macrolet ((rc-function (c) `(stack-ref ,c 0 -2 :lisp))
			    (rc-interactive (c) `(stack-ref ,c 0 -3 :lisp))
			    (rc-test (c) `(stack-ref ,c 0 -4 :lisp))
			    (rc-format (c) `(stack-ref ,c 0 -5 :lisp))
			    (rc-args (c) `(stack-ref ,c 0 -6 :lisp)))
		   (multiple-value-bind ,(cdar basic-restart-clause)
		       (values ,@(subseq `(,context
					   (stack-ref ,context 0 -1 :lisp)) ; name
					 0 (length (cdar basic-restart-clause))))
		     ,@(rest basic-restart-clause))))))
	  ,@(when catch-clause
	      `((t (multiple-value-bind ,(cdar catch-clause)
		       (values ,context ,tag)
		     ,@(rest catch-clause))))))))))

#+ignore
(defun pdc (&rest types)
  (declare (dynamic-extent types))
  (let ((types (or types '(:restarts :bindings :catch))))
    (with-each-dynamic-context ()
      ((:basic-restart context name)
       (when (member :restart types)
	 (format t "~&restart: ~S fmt: ~S/~S [#x~X]" name
		 (rc-format context)
		 (rc-args context)
		 context)))
      ((:binding context name value)
       (declare (ignore context))
       (when (member :bindings types)
	 (format t "~&bind:    ~S => ~Z" name value)))
      ((:catch context tag)
       (declare (ignore context))
       (when (member :catch types)
	 (format t "~&catch:   ~Z: ~S" tag tag))))))
