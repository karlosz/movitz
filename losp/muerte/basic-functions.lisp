;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 2001-2004, 
;;;;    Department of Computer Science, University of Troms�, Norway.
;;;; 
;;;;    For distribution policy, see the accompanying file COPYING.
;;;; 
;;;; Filename:      basic-functions.lisp
;;;; Description:   
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Tue Sep  4 18:41:57 2001
;;;;                
;;;; $Id: basic-functions.lisp,v 1.1 2004/01/13 11:05:05 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(require :muerte/basic-macros)
(require :muerte/setf)
(require :muerte/typep)
(provide :muerte/basic-functions)

(in-package muerte)

(defun eq (x y)
  "Return TRUE iff X and Y are the same."
  (eq x y))

(defun not (x)
  (not x))

(defmacro numargs ()
  `(with-inline-assembly (:returns :ecx)
     (:movzxb :cl :ecx)
     (:shll ,movitz::+movitz-fixnum-shift+ :ecx)))

(defmacro call-function-from-lexical (lexical)
  `(with-inline-assembly (:returns :multiple-values)
     (:compile-form (:result-mode :esi) ,lexical)
     (:xorb :cl :cl)
     (:call (:esi ,(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector)))))

(defun funcall%0ops (function)
  (with-inline-assembly (:returns :multiple-values)
    (:compile-form (:result-mode :esi) (etypecase function
					 (symbol (symbol-function function))
					 (compiled-function function)))
    (:compile-form (:result-mode :edx) function)
    (:xorl :ecx :ecx)
    (:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector)))))

#+ignore
(defun funcall%1ops (function-name arg0)
  (funcall%1ops function-name arg0)	; compiler-macro
  #+ignore (with-inline-assembly (:returns :multiple-values)
	     (:compile-form (:result-mode :esi) (etypecase function-name
						  (symbol (symbol-function function-name))
						  (compiled-function function-name)))
	     (:compile-form (:result-mode :edx) function-name)
	     (:compile-form (:result-mode :eax) arg0)
	     (:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector%1op)))))

#+ignore
(defun funcall%2ops (function arg0 arg1)
  (funcall%2ops function arg0 arg1)	; compiler-macro.
  #+ignore (with-inline-assembly (:returns :multiple-values)
	     (:compile-form (:result-mode :esi) (etypecase function
						  (symbol (symbol-function function))
						  (compiled-function function)))
	     (:compile-form (:result-mode :edx) function)
	     (:compile-form (:result-mode :eax) arg0)
	     (:compile-form (:result-mode :ebx) arg1)
	     (:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector%2op)))))
  
(defun funcall (function-or-name &rest args)
  (numargs-case
   (1 (function-or-name)
      (with-inline-assembly (:returns :multiple-values)
	(:compile-form (:result-mode :esi) (etypecase function-or-name
					     (symbol (symbol-function function-or-name))
					     (compiled-function function-or-name)))
	(:compile-form (:result-mode :edx) function-or-name)
	(:xorl :ecx :ecx)
	(:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector)))))
   (2 (function-or-name arg0)
      (funcall%1ops function-or-name arg0))
   (3 (function-or-name arg0 arg1)
      (funcall%2ops function-or-name arg0 arg1))
   (t (function-or-name &rest args)
      (declare (dynamic-extent args))
      (let ((function (typecase function-or-name
			(symbol (symbol-function function-or-name))
			(compiled-function function-or-name)
			(t (error "Not a function: ~S" function-or-name))))
	    (x args))
	(macrolet ((next (x) `(setf ,x (cdr ,x))))
	  (with-inline-assembly (:returns :nothing)
	    (:compile-form (:result-mode :edx) function-or-name))
	  (cond
	   ((not x)			; 0 args
	    (with-inline-assembly (:returns :multiple-values)
	      (:compile-form (:result-mode :esi) function)
	      (:xorl :ecx :ecx)
	      (:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector)))))
	   ((not (next x))		; 1 args
	    (with-inline-assembly (:returns :multiple-values)
	      (:compile-form (:result-mode :eax) args)
	      (:movl (:eax -1) :eax)	; arg0
	      (:compile-form (:result-mode :esi) function)
	      (:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector%1op)))))
	   ((not (next x))		; 2 args
	    (with-inline-assembly (:returns :multiple-values)
	      (:compile-form (:result-mode :ebx) args)
	      (:movl (:ebx -1) :eax)	; arg0
	      (:movl (:ebx 3) :ebx)	; ebx = (cdr ebx)
	      (:movl (:ebx -1) :ebx)	; ebx = (car ebx) = arg1
	      (:compile-form (:result-mode :esi) function)
	      (:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector%2op)))))
	   ((not (next x))		; 3 args
	    (with-inline-assembly (:returns :multiple-values)
	      (:compile-form (:result-mode :ecx) args)
	      (:movl (:ecx -1) :eax)	; arg0
	      (:movl (:ecx 3) :ecx)	; ecx = (cdr ebx)
	      (:movl (:ecx -1) :ebx)	; ecx = (car ebx) = arg1
	      (:movl (:ecx 3) :ecx)	; ecx = (cdr ebx)
	      (:pushl (:ecx -1))	; arg2
	      (:compile-form (:result-mode :esi) function)
	      (:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector%3op)))))
	   (t (with-inline-assembly (:returns :multiple-values)
		(:compile-form (:result-mode :eax) args)
		(:movl (:eax 3) :eax)	; eax = (cdr eax)
		(:movl (:eax 3) :eax)	; eax = (cdr eax)

		(:xorl :ecx :ecx)
		(:movb 2 :cl)

	       copy-args-loop
		(:incl :ecx)
		(:pushl (:eax -1))	; (push (car eax))
		(:movl (:eax 3) :eax)	; eax = (cdr eax)
		(:leal (:eax 7) :ebx)	; test for nil
		(:testb 7 :bl)
		(:je 'copy-args-loop)	; while (consp eax)

		(:movl :edi :ebx)
		(:compile-form (:result-mode :ebx) args)
		(:movl (:ebx -1) :eax)	; eax = (first args)
		(:movl (:ebx 3) :ebx)
		(:movl (:ebx -1) :ebx)	; ebx = (second args)

		(:cmpl #x7f :ecx)
		(:ja '(:sub-program (normalize-ecx)
		       (:shll 8 :ecx)
		       (:movb #xff :cl)
		       (:jmp 'ecx-ok)))
	       ecx-ok
		(:compile-form (:result-mode :esi) function)
		(:call (:esi #.(movitz::slot-offset 'movitz::movitz-funobj 'movitz::code-vector)))))))))))

(defun apply (function &rest args)
  (numargs-case
   (2 (function args)
      (with-inline-assembly-case ()
	(do-case (t :multiple-values :labels (ecx-ok))
	  (:compile-two-forms (:eax :ebx) function args)
	  ;; Load (function function) into :esi
	  (:leal (:eax -7) :ecx)
	  (:andb 7 :cl)
	  (:jne 'not-symbol)
	  (:movl (:eax #.(bt:slot-offset 'movitz::movitz-symbol 'movitz::function-value))
		 :esi)
	  (:jmp 'esi-ok)
	 not-symbol
	  (:cmpb 7 :cl)
	  (:jne '(:sub-program (not-a-funobj)
		  (:compile-form (:result-mode :ignore)
		   (error "Can't apply non-function ~W." function))))
	  (:cmpb #.(movitz::tag :funobj)
		 (:eax #.(bt:slot-offset 'movitz::movitz-funobj 'movitz::type)))
	  (:jne 'not-a-funobj)
	  (:movl :eax :esi)
	 esi-ok
	  (:leal (:ebx #.(cl:- (movitz::image-nil-word movitz::*image*))) :ecx)
	  (:jecxz 'zero-args)
	  (:testb 3 :cl)
	  (:jz 'more-than-zero-args)
	 zero-args
	  (:xorl :ecx :ecx)
	  (:compile-form (:result-mode :edx) function)
	  (:call (:esi #.(bt:slot-offset 'movitz::movitz-funobj 'movitz::code-vector)))
	  (:jmp 'apply-done)
	 more-than-zero-args
	  (:movl (:ebx -1) :eax)
	  (:movl (:ebx 3) :ebx)
	  (:leal (:ebx #.(cl:- (movitz::image-nil-word movitz::*image*))) :ecx)
	  (:jecxz 'one-args)
	  (:testb 3 :cl)
	  (:jz 'more-than-one-args)
	 one-args
	  (:compile-form (:result-mode :edx) function)
	  (:call (:esi #.(bt:slot-offset 'movitz::movitz-funobj 'movitz::code-vector%1op)))
	  (:jmp 'apply-done)
	 more-than-one-args
	  (:movl (:ebx -1) :edx)
	  (:xchgl :ebx :edx)
	  (:movl (:edx 3) :edx)
	  (:leal (:edx #.(cl:- (movitz::image-nil-word movitz::*image*))) :ecx)
	  (:jecxz 'two-args)
	  (:testb 3 :cl)
	  (:jz 'more-than-two-args)
	 two-args
	  (:compile-form (:result-mode :edx) function)
	  (:call (:esi #.(bt:slot-offset 'movitz::movitz-funobj 'movitz::code-vector%2op)))
	  (:jmp 'apply-done)
	 more-than-two-args
	  (:pushl (:edx -1))
	  (:movl (:edx 3) :edx)
	  (:leal (:edx #.(cl:- (movitz::image-nil-word movitz::*image*))) :ecx)
	  (:jecxz 'three-args)
	  (:testb 3 :cl)
	  (:jz 'more-than-three-args)
	 three-args
	  (:compile-form (:result-mode :edx) function)
	  (:call (:esi #.(bt:slot-offset 'movitz::movitz-funobj 'movitz::code-vector%3op)))
	  (:jmp 'apply-done)
	 more-than-three-args
	  (:pushl (:edx -1))
	  (:movl (:edx 3) :edx)
	  (:leal (:edx #.(cl:- (movitz::image-nil-word movitz::*image*))) :ecx)
	  (:jecxz 'no-more-args)
	  (:testb 3 :cl)
	  (:jz 'more-than-three-args)
	 no-more-args
	  ;; Calculate numargs from (esp-ebp)..
	  (:leal (:ebp -8 8) :ecx)
	  (:subl :esp :ecx)
	  (:shrl 2 :ecx)
	  ;; Encode ECX
	  (:testb :cl :cl)
	  (:jns 'ecx-ok)
	  (:shll 8 :ecx)
	  (:movb #xff :cl)
	 ecx-ok
	  (:compile-form (:result-mode :edx) function)
	  (:call (:esi #.(bt:slot-offset 'movitz::movitz-funobj 'movitz::code-vector)))
	 apply-done
	  ;; Don't need to restore ESP because we'll be exiting this stack-frame
	  ;; now anyway.
	  )))
   (3 (function &rest args)
      (declare (dynamic-extent args))
      ;; spread out args, which we know is length 2.
      (setf (cdr args) (cadr args))
      (apply function args))
   (t (function &rest args)
      (declare (dynamic-extent args))
      ;; spread out args.
      (cond
       ((null args)
	(error "Too few arguments to APPLY."))
       ((null (cdr args))
	(apply function (car args)))
       (t (let* ((second-last-cons (last args 2))
		 (last-cons (cdr second-last-cons)))
	    (setf (cdr second-last-cons) (car last-cons))
	    (apply function args)))))))

(defun values (&rest objects)
  (numargs-case
   (1 (x)
      (with-inline-assembly (:returns :multiple-values)
	(:compile-form (:result-mode :eax) x)
	(:clc)))
   (2 (x y)
      (with-inline-assembly (:returns :multiple-values)
	(:compile-two-forms (:eax :ebx) x y)
	(:movl 2 :ecx)
	(:stc)))
   (3 (x y z)
      (with-inline-assembly (:returns :multiple-values)
	(:compile-two-forms (:eax :ebx) x y)
	((:fs-override) :movl 1 (:edi #.(movitz::global-constant-offset 'num-values)))
	(:compile-form (:result-mode :ecx) z)
	((:fs-override) :movl :ecx (:edi #.(movitz::global-constant-offset 'values)))
	(:movl 3 :ecx)
	(:stc)))
   (t (&rest objects)
      (declare (without-function-prelude)
	       (ignore objects))
      (with-inline-assembly (:returns :multiple-values)
	(:cmpb #.movitz::+movitz-multiple-values-limit+ :cl)
	(:ja '(:sub-program (too-many-values)
	       (:compile-form (:result-mode :ignore)
		(error "Too many values: #x~X."
		 (with-inline-assembly (:returns :eax)
		   (:leal ((:ecx #.movitz::+movitz-fixnum-factor+)) :eax))))))
	(:andl #x7f :ecx)
	(:jz 'done)
	(:subl 2 :ecx)
	(:jc 'copy-done)
	((:fs-override) :movl :ecx (:edi #.(movitz::global-constant-offset 'num-values)))
	(:pushl :eax)
	(:xorl :eax :eax)
       copy-loop
	(:movl (:ebp (:ecx 4) 4) :edx)
	((:fs-override) :movl :edx (:edi (:eax 4) #.(movitz::global-constant-offset 'values)))
	(:addl 1 :eax)
	(:subl 1 :ecx)
	(:jnc 'copy-loop)
	(:popl :eax)
	((:fs-override) :movl (:edi #.(movitz::global-constant-offset 'num-values))
			:ecx)
       copy-done
	(:addl 2 :ecx)
	(:jnz 'done)
	(:movl :edi :eax)
       done
	(:stc)))))

(defun values-list (list)
  (apply #'values list))

(defun ensure-funcallable (x)
  (typecase x
    (symbol
     (symbol-function x))
    (compiled-function
     x)
    (t (error "Not a function: ~S" x))))

(defun get-global-property (property)
  (getf (load-global-constant global-properties) property))

(define-compiler-macro object-location (object)
  `(with-inline-assembly (:returns :eax)
     (:compile-form (:result-mode :eax) ,object)
     (:andb #xf8 :al)))
  
(defun object-location (object)
  "The location is the object's address divided by fixnum-factor."
  (object-location object))


(defun halt-cpu ()
  (halt-cpu))