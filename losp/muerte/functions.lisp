;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 2001-2004, 
;;;;    Department of Computer Science, University of Troms�, Norway.
;;;; 
;;;;    For distribution policy, see the accompanying file COPYING.
;;;; 
;;;; Filename:      functions.lisp
;;;; Description:   Misc. function-oriented functions
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Tue Mar 12 22:58:54 2002
;;;;                
;;;; $Id: functions.lisp,v 1.1 2004/01/13 11:05:05 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(require :muerte/basic-macros)
(require :muerte/setf)
(provide :muerte/functions)

(In-package muerte)

(defun identity (x) x)

(defun constantly-prototype (&rest ignore)
  (declare (ignore ignore))
  'value)

(define-compiler-macro constantly (&whole form value-form)
  (cond
   ((movitz:movitz-constantp value-form)
    (let ((value (movitz:movitz-eval value-form)))
      `(make-prototyped-function (constantly ,value)
				 constantly-prototype
				 (value ,value))))
   (t (error "Non-constant constantly forms not yet supported: ~S" form)
      form)))

(defun complement-prototype (&rest args)
  (declare (dynamic-extent args))
  (not (apply 'function args)))

(define-compiler-macro complement (&whole form function-form)
  (cond
   ((movitz:movitz-constantp function-form)
    (let ((function (movitz:movitz-eval function-form)))
      `(make-prototyped-function (complement ,function)
				 complement-prototype
				 (function ,function))))
   ((and (listp function-form)
	 (eq 'function (first function-form))
	 (symbolp (second function-form))
	 (typep (movitz:movitz-eval (translate-program function-form :cl :muerte.cl))
		'movitz:movitz-funobj))
    `(make-prototyped-function (complement ,function-form)
			       complement-prototype
			       (function ,(movitz:movitz-eval (translate-program function-form
									      :cl :muerte.cl)))))
   (t #+ignore (error "Non-constant complement forms not yet supported: ~S" form)
      form)))

(defun complement (function)
  (lambda (&rest args)
    (declare (dynamic-extent args))
    (not (apply function args))))

(defun unbound-function (&edx edx &rest args)
  (declare (dynamic-extent args) (ignore args))
  (let ((function-name (typecase edx
			 (symbol
			  edx)
			 (compiled-function
			  (funobj-name edx))
			 (t '(unknown)))))
    (error 'undefined-function :name function-name)
    #+ignore (error "Unbound function-name ~S called with arguments ~S." function-name args)))

;;; funobj object

(defun funobj-type (funobj)
  (check-type funobj compiled-function)
  (with-inline-assembly (:returns :untagged-fixnum-ecx)
    (:xorl :ecx :ecx)
    (:compile-form (:result-mode :eax) funobj)
    (:movb (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:funobj-type)) :cl)))

(defun funobj-code-vector (funobj)
  (check-type funobj compiled-function)
  (with-inline-assembly (:returns :eax)
    (:compile-form (:result-mode :eax) funobj)
    (:movl (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)) :eax)
    (:subl 2 :eax)))			; this cell stores word+2

(defun (setf funobj-code-vector) (code-vector funobj)
  (check-type funobj compiled-function)
  (check-type code-vector vector-u8)
  (with-inline-assembly (:returns :eax)
    (:compile-form (:result-mode :ebx) funobj)
    (:compile-form (:result-mode :eax) code-vector)
    (:addl 2 :eax)			; this cell stores word+2
    (:movl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)))
    (:subl 2 :eax)))

(defun funobj-code-vector%1op (funobj)
  "This slot is not a lisp value, it is a direct address to code entry point. In practice it is either
a pointer into the regular code-vector, or it points (with offset 2) to another vector entirely.
The former is represented as a lisp integer that is the index into the code-vector, the latter is represented
as that vector."
  (check-type funobj compiled-function)
  (with-inline-assembly (:returns :eax)
    (:compile-form (:result-mode :eax) funobj)
    (:movl (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)) :ebx) ; EBX = code-vector
    (:movl (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%1op)) :eax) ; EAX = code-vector%1op
    ;; determine if EAX is a pointer into EBX
    (:cmpl :ebx :eax)
    (:jl 'return-vector)
    (:andb #xf8 :bl)
    (:addl #x100 :ebx)
    (:cmpl :ebx :eax)
    (:jg 'return-vector)
    ;; return the integer offset EAX-EBX
    (:subl #x100 :ebx)
    (:subl :ebx :eax)
    (:shll #.movitz:+movitz-fixnum-shift+ :eax)
    (:jmp 'done)
    return-vector
    (:subl 2 :eax)
    done))				; this cell stores word+2

(defun (setf funobj-code-vector%1op) (code-vector funobj)
  (check-type funobj compiled-function)
  (etypecase code-vector
    (vector-u8
     (with-inline-assembly (:returns :nothing)
       (:compile-form (:result-mode :ebx) funobj)
       (:compile-form (:result-mode :eax) code-vector)
       (:addl 2 :eax)			; this cell stores word+2
       (:movl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%1op)))))
    (integer
     (with-inline-assembly (:returns :nothing)
       (:compile-form (:result-mode :ebx) funobj)
       (:movl (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)) :eax)
       (:movl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%1op)))
       (:compile-form (:result-mode :untagged-fixnum-eax) code-vector)
       (:addl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%1op)))
       (:xorl :eax :eax))))
  code-vector)

(defun funobj-code-vector%2op (funobj)
  "This slot is not a lisp value, it is a direct address to code entry point. In practice it is either
a pointer into the regular code-vector, or it points (with offset 2) to another vector entirely.
The former is represented as a lisp integer that is the index into the code-vector, the latter is represented
as that vector."
  (check-type funobj compiled-function)
  (with-inline-assembly (:returns :eax)
    (:compile-form (:result-mode :eax) funobj)
    (:movl (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)) :ebx) ; EBX = code-vector
    (:movl (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%2op)) :eax) ; EAX = code-vector%1op
    ;; determine if EAX is a pointer into EBX
    (:cmpl :ebx :eax)
    (:jl 'return-vector)
    (:andb #xf8 :bl)
    (:addl #x100 :ebx)
    (:cmpl :ebx :eax)
    (:jg 'return-vector)
    ;; return the integer offset EAX-EBX
    (:subl #x100 :ebx)
    (:subl :ebx :eax)
    (:shll #.movitz:+movitz-fixnum-shift+ :eax)
    (:jmp 'done)
    return-vector
    (:subl 2 :eax)
    done))

(defun (setf funobj-code-vector%2op) (code-vector funobj)
  (check-type funobj compiled-function)
  (etypecase code-vector
    (vector-u8
     (with-inline-assembly (:returns :nothing)
       (:compile-form (:result-mode :ebx) funobj)
       (:compile-form (:result-mode :eax) code-vector)
       (:addl 2 :eax)			; this cell stores word+2
       (:movl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%2op)))))
    (integer
     (with-inline-assembly (:returns :nothing)
       (:compile-form (:result-mode :ebx) funobj)
       (:movl (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)) :eax)
       (:movl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%2op)))
       (:compile-form (:result-mode :untagged-fixnum-eax) code-vector)
       (:addl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%2op)))
       (:xorl :eax :eax))))
  code-vector)

(defun funobj-code-vector%3op (funobj)
  "This slot is not a lisp value, it is a direct address to code entry point. In practice it is either
a pointer into the regular code-vector, or it points (with offset 2) to another vector entirely.
The former is represented as a lisp integer that is the index into the code-vector, the latter is represented
as that vector."
  (check-type funobj compiled-function)
  (with-inline-assembly (:returns :eax)
    (:compile-form (:result-mode :eax) funobj)
    (:movl (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)) :ebx) ; EBX = code-vector
    (:movl (:eax #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%3op)) :eax) ; EAX = code-vector%1op
    ;; determine if EAX is a pointer into EBX
    (:cmpl :ebx :eax)
    (:jl 'return-vector)
    (:andb #xf8 :bl)
    (:addl #x100 :ebx)
    (:cmpl :ebx :eax)
    (:jg 'return-vector)
    ;; return the integer offset EAX-EBX
    (:subl #x100 :ebx)
    (:subl :ebx :eax)
    (:shll #.movitz:+movitz-fixnum-shift+ :eax)
    (:jmp 'done)
    return-vector
    (:subl 2 :eax)
    done))

(defun (setf funobj-code-vector%3op) (code-vector funobj)
  (check-type funobj compiled-function)
  (etypecase code-vector
    (vector-u8
     (with-inline-assembly (:returns :nothing)
       (:compile-form (:result-mode :ebx) funobj)
       (:compile-form (:result-mode :eax) code-vector)
       (:addl 2 :eax)			; this cell stores word+2
       (:movl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%3op)))))
    (integer
     (with-inline-assembly (:returns :nothing)
       (:compile-form (:result-mode :ebx) funobj)
       (:movl (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector)) :eax)
       (:movl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%3op)))
       (:compile-form (:result-mode :untagged-fixnum-eax) code-vector)
       (:addl :eax (:ebx #.(bt::slot-offset 'movitz:movitz-funobj 'movitz:code-vector%3op)))
       (:xorl :eax :eax))))
  code-vector)

(defun funobj-name (funobj)
  (check-type funobj compiled-function)
  (movitz-accessor funobj movitz-funobj name))

(defun (setf funobj-name) (name funobj)
  (check-type funobj compiled-function)
  ;; (check-type name (or symbol list)
  (setf-movitz-accessor (funobj movitz-funobj name) name))

(defun funobj-lambda-list (funobj)
  (check-type funobj compiled-function)
  (movitz-accessor funobj movitz-funobj lambda-list))

(defun (setf funobj-lambda-list) (lambda-list funobj)
  (check-type funobj compiled-function)
  (check-type lambda-list list)
  (setf-movitz-accessor (funobj movitz-funobj lambda-list) lambda-list))

(defun funobj-num-constants (funobj)
  (check-type funobj compiled-function)
  (movitz-accessor-u16 funobj movitz-funobj num-constants))

(defun (setf funobj-num-constants) (num-constants funobj)
  (check-type funobj compiled-function)
  (check-type num-constants (unsigned-byte 16))
  (set-movitz-accessor-u16 funobj movitz-funobj num-constants num-constants))

(defun funobj-num-jumpers (funobj)
  (check-type funobj compiled-function)
  (movitz-accessor-u16 funobj movitz-funobj num-jumpers))

(defun (setf funobj-num-jumpers) (num-jumpers funobj)
  (check-type funobj compiled-function)
  (check-type num-jumpers (unsigned-byte 16))
  (set-movitz-accessor-u16 funobj movitz-funobj num-jumpers num-jumpers))

(defun funobj-constant-ref (funobj index)
  (check-type funobj compiled-function)
  (assert (below index (funobj-num-constants funobj)) (index)
    "Index ~D out of range, ~S has ~D constants." index funobj (funobj-num-constants funobj))
  (if (>= index (funobj-num-jumpers funobj))
      (memref funobj #.(bt:slot-offset 'movitz:movitz-funobj 'movitz:constant0) index :lisp)
    (without-gc
     (with-inline-assembly (:returns :eax)
       (:compile-two-forms (:eax :untagged-fixnum-ecx) funobj index)
       (:movl (:eax #.(bt:slot-offset 'movitz:movitz-funobj 'movitz:code-vector))
	      :ebx)
       (:negl :ebx)
       (:addl ((:ecx 4) :eax #.(bt:slot-offset 'movitz:movitz-funobj 'movitz:constant0))
	      :ebx)
       (:leal ((:ebx #.movitz:+movitz-fixnum-factor+)) :eax)
       (:xorl :ebx :ebx)))))

(defun (setf funobj-constant-ref) (value funobj index)
  (check-type funobj compiled-function)
  (assert (below index (funobj-num-constants funobj)) (index)
    "Index ~D out of range, ~S has ~D constants." index funobj (funobj-num-constants funobj))
  (if (>= index (funobj-num-jumpers funobj))
      (setf (memref funobj #.(bt:slot-offset 'movitz:movitz-funobj 'movitz:constant0)
		    index :lisp)
	value)
    (progn
      (assert (below value (length (funobj-code-vector funobj))) (value)
	"The jumper value ~D is invalid because the code-vector's size is ~D."
	value (length (funobj-code-vector funobj)))
      (without-gc
       (with-inline-assembly (:returns :nothing)
	 (:compile-two-forms (:eax :untagged-fixnum-ecx) funobj index)
	 (:leal ((:ecx 4) :eax #.(bt:slot-offset 'movitz:movitz-funobj 'movitz:constant0))
		:ebx)			; dest. address into ebx.
	 (:compile-form (:result-mode :untagged-fixnum-ecx) value)
	 (:addl (:eax #.(bt:slot-offset 'movitz:movitz-funobj 'movitz:code-vector))
		:ecx)
	 (:movl :ecx (:ebx))
	 (:xorl :ebx :ebx)))
      value)))

(defun funobj-debug-info (funobj)
  (check-type funobj compiled-function)
  (movitz-accessor-u16 funobj movitz-funobj debug-info))

(defun make-funobj (&key (name :unnamed)
			 (code-vector (funobj-code-vector #'constantly-prototype))
			 (constants nil)
			 ;; (num-constants (length constants))
			 lambda-list)
  (setf code-vector
    (etypecase code-vector
      (vector-u8 code-vector)
      (list
       (make-array (length code-vector)
		   :element-type 'u8
		   :initial-contents code-vector))
      (vector 
       (make-array (length code-vector)
		   :element-type 'u8
		   :initial-contents code-vector))))
  (let ((funobj (inline-malloc (+ #.(bt:sizeof 'movitz:movitz-funobj)
				  (* 4 (length constants)))
			       :other-tag :funobj)))
    (setf (funobj-name funobj) name
	  (funobj-code-vector funobj) code-vector
	  ;; revert to default trampolines for now..
	  (funobj-code-vector%1op funobj) (get-global-property :trampoline-funcall%1op)
	  (funobj-code-vector%2op funobj) (get-global-property :trampoline-funcall%2op)
	  (funobj-code-vector%3op funobj) (get-global-property :trampoline-funcall%3op)
	  (funobj-lambda-list funobj) lambda-list
	  (funobj-num-constants funobj) (length constants))
    (do* ((i 0 (1+ i))
	  (p constants (cdr p))
	  (x (car p)))
	((endp p))
      (setf (funobj-constant-ref funobj i) x))
    funobj))


(defun install-function (name constants code-vector)
  (let ((funobj (make-funobj :name name :constants constants :code-vector code-vector)))
    (warn "installing ~S for ~S.." funobj name)
    (setf (symbol-function name) funobj)))

(defun replace-funobj (dst src &optional (name (funobj-name src)))
  "Copy each element of src to dst. Dst's num-constants must be initialized,
so that we can be reasonably sure of dst's size."
  (assert (= (funobj-num-constants src)
	     (funobj-num-constants dst)))
  (setf (funobj-name dst) name
	(funobj-num-jumpers dst) (funobj-num-jumpers src)
	(funobj-code-vector dst) (funobj-code-vector src)
	(funobj-code-vector%1op dst) (funobj-code-vector%1op src)
	(funobj-code-vector%2op dst) (funobj-code-vector%2op src)
	(funobj-code-vector%3op dst) (funobj-code-vector%3op src)
	(funobj-lambda-list dst) (funobj-lambda-list src))
  (dotimes (i (funobj-num-constants src))
    (setf (funobj-constant-ref dst i)
      (funobj-constant-ref src i)))
  dst)

(defun copy-funobj (old-funobj &optional (name (funobj-name old-funobj)))
  (let* ((num-constants (funobj-num-constants old-funobj))
	 (funobj (inline-malloc (+ #.(bt:sizeof 'movitz:movitz-funobj)
				   (* 4 num-constants))
				:other-tag :funobj)))
    (setf (funobj-num-constants funobj) num-constants)
    (replace-funobj funobj old-funobj name)))


(defun install-funobj-name (name funobj)
  (setf (funobj-name funobj) name)
  funobj)

(defun fdefinition (function-name)
  (etypecase function-name
    (symbol
     (symbol-function function-name))
    ((cons (eql setf))
     (symbol-function (gethash (cadr function-name)
			       (get-global-property :setf-namespace))))))

(defun (setf fdefinition) (value function-name)
  (etypecase function-name
    (symbol
     (setf (symbol-function function-name) value))
    ((cons (eql setf))
     (let* ((setf-namespace (get-global-property :setf-namespace))
	    (setf-name (cadr function-name))
	    (setf-symbol (or (gethash setf-name setf-namespace)
			     (setf (gethash setf-name setf-namespace)
			       (make-symbol (format nil "~A-~A" 'setf 'setf-name))))))
       (setf (symbol-function setf-symbol)
	 value)))))

(defun fmakunbound (function-name)
  (setf (fdefinition function-name)
    (load-global-constant unbound-function)))