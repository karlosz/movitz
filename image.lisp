;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 2001,2000, 2002-2004,
;;;;    Department of Computer Science, University of Troms�, Norway.
;;;; 
;;;; Filename:      image.lisp
;;;; Description:   Construction of LispOS images.
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Sun Oct 22 00:22:43 2000
;;;; Distribution:  See the accompanying file COPYING.
;;;;                
;;;; $Id: image.lisp,v 1.1 2004/01/13 11:04:59 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(in-package movitz)

(define-binary-class movitz-constant-block (movitz-heap-object)
  ((constant-block-start :binary-type :label) ; keep this at the top.
   (name
    :binary-type word
    :initform :global
    :map-binary-write 'movitz-read-and-intern
    :map-binary-read-delayed 'movitz-word)
   (type
    :binary-type other-type-byte
    :initform :run-time-context)
   (padding
    :binary-type 3)
   (fast-car
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-cdr
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-car-ebx
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-cdr-ebx
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   ;; tag-specific class-of primitive-functions
   (fast-class-of :binary-type :label)
   (fast-class-of-even-fixnum		; 0000
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-class-of-cons			; 1111
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-class-of-character		; 2222
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-class-of-tag3			; 3333
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-class-of-odd-fixnum		; 4444
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-class-of-null			; 5555
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-class-of-other			; 6666
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-class-of-symbol		; 7777
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   ;; various constants
   (push-current-values
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (pop-current-values
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   ;; function global constants
   (unbound-function
    :binary-type word
    :binary-tag :global-function
    :map-binary-read-delayed 'movitz-word
    :map-binary-write 'movitz-intern)   
   ;; per thread parameters
   (dynamic-env
    :binary-type lu32
    :initform 0)
   ;; More per-thread parameters
   (restart-tag
    :binary-type word
    :map-binary-read-delayed 'movitz-word
    :map-binary-write 'movitz-read-and-intern
    :initform 'muerte::restart-protect-tag)
   (stack-bottom			; REMEMBER BOCHS!
    :binary-type word
    :initform #x0ff000)
   (stack-top				; stack-top must be right after stack-bottom
    :binary-type word			; in order for the bound instruction to work.
    :initform #x100000)
   ;;
   (unbound-value
    :binary-type word
    :map-binary-read-delayed 'movitz-word
    :map-binary-write 'movitz-read-and-intern
    :initform 'muerte::unbound)
   (unwind-protect-tag
    :binary-type word
    :map-binary-read-delayed 'movitz-word
    :map-binary-write 'movitz-read-and-intern
    :initform 'muerte::unwind-protect-tag)
   (boolean-one :binary-type :label)
   (not-nil				; not-nil, t-symbol and null-cons must be consecutive.
    :binary-type word
    :initform nil
    :map-binary-write 'movitz-read-and-intern
    :map-binary-read-delayed 'movitz-word)
   (boolean-zero :binary-type :label)
   (t-symbol
    :binary-type word
    :initarg :t-symbol
    :map-binary-write 'movitz-intern
    :map-binary-read-delayed 'movitz-word)
   (null-cons
    :binary-type movitz-nil
    :initarg :null-cons)
   (null-sym
    :binary-type movitz-nil-symbol
    :reader movitz-constant-block-null-symbol
    :initarg :null-sym)
   ;; primitive functions global constants
   (dynamic-find-binding
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (dynamic-load
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (dynamic-store
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (dynamic-locate-catch-tag
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (dynamic-unwind
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (assert-1arg
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (assert-2args
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (assert-3args
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (decode-args-1or2
    :map-binary-write 'movitz-intern-code-vector
    :binary-tag :primitive-function
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-type code-vector-word)
   (keyword-search
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function
    :binary-type code-vector-word)
   (restify-dynamic-extent
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (malloc
    :binary-type code-vector-word
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (malloc-buffer
    :binary-type lu32
    :initform 0)
   (fast-cdr-car
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-cons
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (ensure-heap-cons-variable
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-compare-two-reals
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-compare-fixnum-real
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (fast-compare-real-fixnum
    :binary-type code-vector-word
    :initform nil
    :map-binary-write 'movitz-intern-code-vector
    :map-binary-read-delayed 'movitz-word-code-vector
    :binary-tag :primitive-function)
   (num-values
    :binary-type lu32
    :initform 0)
   (values
    :binary-type #.(* 4 +movitz-multiple-values-limit+))

   (default-interrupt-trampoline
       :map-binary-write 'movitz-intern-code-vector
     :binary-tag :primitive-function
     :map-binary-read-delayed 'movitz-word-code-vector
     :binary-type code-vector-word)
   (complicated-class-of
    :binary-type word
    :binary-tag :global-function
    :map-binary-read-delayed 'movitz-word
    :map-binary-write 'movitz-intern)   
   ;; Some well-known classes
   (the-class-t
    :binary-type word
    :initform t
    :map-binary-write (lambda (x type)
			(declare (ignore type))
			(movitz-read-and-intern (funcall 'muerte::movitz-find-class x)
						'word))
    :map-binary-read-delayed 'movitz-word)
   (the-class-fixnum
    :binary-type word
    :initform 'fixnum
    :map-binary-write (lambda (x type)
			(declare (ignore type))
			(movitz-read-and-intern (funcall 'muerte::movitz-find-class x)
					     'word))
    :map-binary-read-delayed 'movitz-word)
   (the-class-cons
    :binary-type word
    :initform 'cons
    :map-binary-write (lambda (x type)
			(declare (ignore type))
			(movitz-read-and-intern (funcall 'muerte::movitz-find-class x)
					     'word))
    :map-binary-read-delayed 'movitz-word)
   (the-class-null
    :binary-type word
    :initform 'null
    :map-binary-write (lambda (x type)
			(declare (ignore type))
			(movitz-read-and-intern (funcall 'muerte::movitz-find-class x)
					     'word))
    :map-binary-read-delayed 'movitz-word)
   (the-class-symbol
    :binary-type word
    :initform 'symbol
    :map-binary-write (lambda (x type)
			(declare (ignore type))
			(movitz-read-and-intern (funcall 'muerte::movitz-find-class x)
					     'word))
    :map-binary-read-delayed 'movitz-word)
   (interrupt-handlers
    :binary-type word
    :map-binary-write 'movitz-intern
    :map-binary-read-delayed 'movitz-word
    :initarg :interrupt-handlers
    :accessor movitz-constant-block-interrupt-handlers)
   (interrupt-descriptor-table
    :binary-type word
    :accessor movitz-constant-block-interrupt-descriptor-table
    :initarg :interrupt-descriptor-table
    :map-binary-read-delayed 'movitz-word
    :map-binary-write 'map-idt-to-array)
   (toplevel-funobj
    :binary-type word
    :initform nil
    :accessor movitz-constant-block-toplevel-funobj
    :map-binary-write 'movitz-intern
    :map-binary-read-delayed 'movitz-word)
   (global-properties
    :binary-type word
    :initform nil
    :accessor movitz-constant-block-global-properties
    :map-binary-write 'movitz-intern
    :map-binary-read-delayed 'movitz-word)
   (copy-funobj
    :binary-type word
    ;; :accessor movitz-constant-block-copy-funobj
    :initform 'muerte::copy-funobj
    :map-binary-write (lambda (name type)
			(declare (ignore type))
			(movitz-intern (movitz-env-named-function name))))
   (physical-address-offset
    :binary-type lu32
    :initform (image-ds-segment-base *image*))
   (stack-vector
    :binary-type word
    :initform nil
    :map-binary-write 'movitz-read-and-intern
    :map-binary-read-delayed (lambda (x type)
			       (declare (ignore x type))
			       (movitz-read nil)))
   (self
    :binary-type word
    :initform 6
    :map-binary-read-delayed 'movitz-word)
   (parent
    :binary-type word
    :initform nil
    :map-binary-write 'movitz-read-and-intern
    :map-binary-read-delayed 'movitz-word)
   (align-segment-descriptors :binary-type 4)
   (segment-descriptor-table :binary-type :label)
   (segment-descriptor-0
    :binary-type segment-descriptor
    :initform (make-segment-descriptor))
   (segment-descriptor-global-code	; 1: true flat code segment
    :binary-type segment-descriptor
    :initform (make-segment-descriptor :base 0 :limit #xfffff :type 10 :dpl 0
				       :flags '(s p d/b g)))
   (segment-descriptor-global-data	; 2: true flat data segment
    :binary-type segment-descriptor
    :initform (make-segment-descriptor :base 0 :limit #xfffff ; data segment
				       :type 2 :dpl 0
				       :flags '(s p d/b g)))
   (segment-descriptor-shifted-code	; 3: 1 MB shifted flat code segment
    :binary-type segment-descriptor
    :initform (make-segment-descriptor :base (image-start-address *image*)
				       :limit #xfff00 :type 10 :dpl 0
				       :flags '(s p d/b g)))
   (segment-descriptor-shifted-data	; 4: 1 MB shifted flat data segment
    :binary-type segment-descriptor
    :initform (make-segment-descriptor :base (image-start-address *image*)
				       :limit #xfff00 ; data segment
				       :type 2 :dpl 0
				       :flags '(s p d/b g)))
   (segment-descriptor-thread-context	; 5: same as normal shifted-data for initial context.
    :binary-type segment-descriptor
    :initform (make-segment-descriptor :base (image-start-address *image*)
				       :limit #xfff00 ; data segment
				       :type 2 :dpl 0
				       :flags '(s p d/b g)))
   (segment-descriptor-6
    :binary-type segment-descriptor
    :initform (make-segment-descriptor))
   (segment-descriptor-7
    :binary-type segment-descriptor
    :initform (make-segment-descriptor))
   )
  (:slot-align null-cons -1))

(defmethod movitz-object-offset ((obj movitz-constant-block)) 0)

(defun global-constant-offset (slot-name)
  (check-type slot-name symbol)
  
  (slot-offset 'movitz-constant-block
	       (intern (symbol-name slot-name) :movitz)))

(defun make-movitz-constant-block ()
  (make-instance 'movitz-constant-block
    :t-symbol (movitz-read 't)
    :null-cons *movitz-nil*
    :null-sym (movitz-nil-sym *movitz-nil*)))

(defclass image ()
  ((ds-segment-base
    :initform #x100000
    :accessor image-ds-segment-base)
   (cs-segment-base
    :initform #x100000
    :accessor image-cs-segment-base)))

(defclass symbolic-image (image)
  ((object-hash
    :accessor image-object-hash)	; object => address
   (address-hash
    :accessor image-address-hash)	; address => object
   (cons-pointer
    :accessor image-cons-pointer)
   (read-map-hash
    :initform (make-hash-table :test #'eq) ; lisp object => movitz object
    :reader image-read-map-hash)
   (inverse-read-map-hash
    :initform (make-hash-table :test #'eq) ; lisp object => movitz object
    :reader image-inverse-read-map-hash)
   (oblist
    :reader image-oblist
    :initform (make-hash-table :test #'eq))
   (global-environment
    :initform (make-global-movitz-environment)
    :reader image-global-environment)
   (struct-slot-descriptions
    :initform (make-hash-table :test #'eq)
    :accessor image-struct-slot-descriptions)
   (start-address
    :initarg :start-address
    :accessor image-start-address)
   (symbol-hash-key-counter
    :initform 0
    :type unsigned-byte
    :accessor image-symbol-hash-key-counter)
   (nil-word
    :accessor image-nil-word)
   (t-symbol
    :accessor image-t-symbol)
   (bootblock
    :accessor image-bootblock)
   (movitz-modules
    :initarg :movitz-modules
    :initform nil
    :accessor image-movitz-modules)
   (movitz-features
    :initarg :movitz-features
    :accessor image-movitz-features)
   (called-functions
    :initarg :called-functions
    :initform nil
    :accessor image-called-functions)
   (toplevel-funobj
    :accessor image-toplevel-funobj)
   (constant-block
    :accessor image-constant-block)
   (load-time-funobjs
    :initform ()
    :accessor image-load-time-funobjs)
   (compile-time-variables
    :initform ()
    :accessor image-compile-time-variables)
   (string-constants
    :initform (make-hash-table :test #'equal)
    :reader image-string-constants)
   (cons-constants
    :initform (make-hash-table :test #'equal)
    :reader image-cons-constants)
   (multiboot-header
    :accessor image-multiboot-header)
   (dump-count
    :initform 0
    :accessor dump-count)
   (function-code-sizes
    :initform (make-hash-table :test #'equal)
    :initarg :function-code-sizes
    :reader function-code-sizes)))

(defun unbound-value ()
  (declare (special *image*))
  (slot-value (image-constant-block *image*)
	      'unbound-value))

(defun edi-offset ()
  (declare (special *image*))
  (- (image-nil-word *image*)))

(defmethod image-intern-object ((image symbolic-image) object &optional (size (sizeof object)))
  (assert				; sanity check on "other" storage-types.
      (or (not (typep object 'movitz-heap-object-other))
	  (and (= -6 (slot-offset (type-of object)
				  (first (binary-record-slot-names (type-of object)))))
	       (= -2 (slot-offset (type-of object) 'type))))
      ()
    "The MOVITZ-HEAP-OBJECT-OTHER type ~A is malformed!" (type-of object))
  (etypecase object
    (movitz-nil
     (image-nil-word image))
    (movitz-heap-object
     (+ (movitz-object-offset object)
	(or (gethash object (image-object-hash image))
	    (let* ((alignment (movitz-storage-alignment object))
		   (new-ptr (if (= (movitz-storage-alignment-offset object)
				   (mod (image-cons-pointer image)
					(movitz-storage-alignment object)))
				(image-cons-pointer image)
			      (+ (image-cons-pointer image)
				 (mod (- (image-cons-pointer image))
				      alignment)
				 (movitz-storage-alignment-offset object)))))
	      (setf (gethash new-ptr (image-address-hash image)) object
		    (gethash object (image-object-hash image)) new-ptr
		    (image-cons-pointer image) (+ new-ptr size))
	      new-ptr))))))

(defmethod image-memref ((image symbolic-image) address &optional (errorp nil))
  (let ((obj (gethash address (image-address-hash image))))
    (when (and errorp (not (typep obj 'movitz-object)))
      (error "Found non-movitz-object at image-address #x~X: ~A" address obj))
    obj))

(defmethod search-image ((image symbolic-image) address)
  (loop for a downfrom (logand address -8) by 8
      until (gethash a (image-address-hash image))
      finally (progn 
		;; (warn "Found at ~X: ~S" a (gethash a (image-address-hash image)))
		(return (gethash a (image-address-hash image))))))

(defun search-image-funobj (address &optional (*image* *image*))
  (search-image-funobj-by-image *image* address))

(defmethod search-image-funobj-by-image ((image symbolic-image) address)
  (let ((code-vector (search-image image (1- address))))
    (unless (and (typep code-vector 'movitz-vector)
		 (eq :u8 (movitz-vector-element-type code-vector)))
      (error "Not a code-vector at #x~8,'0X: ~S" address code-vector))
    (let ((offset (- address (movitz-intern-code-vector code-vector))))
      (assert (not (minusp offset)))
      (format t "~&;; Matched code-vector at #x~X with offset ~D.~%"
	      (image-intern-object image code-vector)
	      offset))
    (with-hash-table-iterator (next-object (image-object-hash *image*))
      (loop with more-objects and object
	  do (multiple-value-setq (more-objects object) (next-object))
	  while more-objects
	  when (typecase object
		 (movitz-funobj
		  (when (eq code-vector (movitz-funobj-code-vector object))
		    object))
		 (movitz-symbol
		  (when (eq code-vector (movitz-symbol-value object))
		    (movitz-print object))))
	  collect it))))

(defun search-primitive-function (address &optional (*image* *image*))
  (let ((code-vector (search-image *image* address)))
    (unless (and (typep code-vector 'movitz-vector)
		 (eq :u8 (movitz-vector-element-type code-vector)))
      (error "Not a code-vector at #x~8,'0X: ~S" address code-vector))
    (format t "~&;; Code vector: #x~X" (movitz-intern code-vector))
    (loop for pf-name in (binary-record-slot-names 'movitz-constant-block
						   :match-tags :primitive-function)
	when (= (movitz-intern-code-vector code-vector)
		(binary-slot-value (image-constant-block *image*) pf-name))
	do (format t "~&;; #x~X matches global primitive-function ~W with offset ~D."
		   address pf-name
		   (- address (movitz-intern-code-vector code-vector)))
	and collect pf-name)))



(defun movitz-word (word &optional (type 'word))
  "Return the movitz-object corresponding to (the integer) WORD."
  (assert (eq type 'word))
  (movitz-word-by-image *image* word))

(defun movitz-word-and-print (word)
  (movitz-print (movitz-word word)))

(defmethod movitz-word-by-image ((image symbolic-image) word)
  (case (extract-tag word)
    (#.+fixnum-tags+
     (make-movitz-fixnum
      (make-instance 'movitz-fixnum :value (fixnum-integer word))))
    (:character
     (make-instance 'movitz-character :char (code-char (ldb (byte 8 8) word))))
    (:null
     (image-memref *image* (+ 3 word) t))
    (t (image-memref *image* (logand word #xfffffff8) t))))

(defun movitz-intern-code-vector (object &optional (type 'code-vector-word))
  "Four ways to denote a code-vector: a vector is that vector,
a symbol is considered a primitive-function and the symbol-value is used,
a movitz-funobj is that funobj's code-vector,
a cons is an offset (the car) from some other code-vector (the cdr)."
  (assert (member type '(code-vector-word code-pointer)))
  (etypecase object
    ((or vector movitz-vector)
     (+ 2 (movitz-intern object)))
    ((or symbol movitz-symbol)
     (let ((primitive-code-vector (movitz-symbol-value (movitz-read object))))
       (check-type primitive-code-vector movitz-vector)
       (movitz-intern-code-vector primitive-code-vector type)))
    (movitz-funobj
     (movitz-intern-code-vector (movitz-funobj-code-vector object) type))
    (cons
     ;; a cons denotes an offset (car) from some funobj's (cdr) code-vector.
     (check-type (car object) integer)
     (check-type (cdr object) movitz-funobj)
     (+ (car object) (movitz-intern-code-vector (cdr object) type)))))

(defun movitz-word-code-vector (word &optional (type 'code-vector-word))
  (assert (eq type 'code-vector-word))
  (movitz-word (- word +code-vector-word-offset+)))

(defun copy-hash-table (x)
  (let ((y (make-hash-table :test (hash-table-test x))))
    (maphash (lambda (k v)
	       (setf (gethash k y) v))
	     x)
    y))

(defun make-movitz-image (start-address)
  (let ((*image* (make-instance 'symbolic-image
		   :start-address start-address
		   :movitz-features '(:movitz)
		   :function-code-sizes
		   (if (boundp '*image*)
		       (copy-hash-table (function-code-sizes *image*))
		     (make-hash-table :test #'equal)))))
    (setf (image-nil-word *image*)
      (1+ (- (slot-offset 'movitz-constant-block 'null-cons)
	     (slot-offset 'movitz-constant-block 'constant-block-start))))
    (format t "~&;; NIL value: #x~X.~%" (image-nil-word *image*))
    (assert (eq :null (extract-tag (image-nil-word *image*))) ()
      "NIL value #x~X has tag ~D, but it must be ~D."
      (image-nil-word *image*)
      (ldb (byte 3 0) (image-nil-word *image*))
      (tag :null))
    (setf (image-constant-block *image*) (make-movitz-constant-block))
    (setf (movitz-constant-block-interrupt-handlers (image-constant-block *image*))
      (movitz-read (make-array 256 :initial-element 'muerte::interrupt-default-handler)))
    (setf (movitz-constant-block-interrupt-descriptor-table (image-constant-block *image*))
      (movitz-read (make-initial-interrupt-descriptors)))
    (setf (image-t-symbol *image*) (movitz-read t))
    ;; (warn "NIL value: #x~X" (image-nil-word *image*))
    *image*))

(defun find-primitive-function (name)
  "Given the NAME of a primitive function, look up 
   that function's code-vector."
  (let ((code-vector
	 (movitz-symbol-value (movitz-read name))))
    (assert (and code-vector
		 (not (eq 'muerte::unbound code-vector)))
	()
      "Global constant primitive function ~S is not defined!" name)
    (check-type code-vector movitz-vector)
    code-vector))

(defun create-image (&key (init-file *default-image-init-file*)
			  (start-address #x100000))
  (#+allegro excl:tenuring #-allegro progn
	     (psetq *image* (let ((*image* (make-movitz-image start-address)))
			      (when init-file
				(movitz-compile-file init-file))
			      *image*)
		    *i* (when (boundp '*image*) *image*))
	     ;; #+acl (excl:gc)
	     *image*))

(defun dump-image (&key (path *default-image-file*) ((:image *image*) *image*)
			(multiboot-p t) ignore-dump-count)
  "When <multiboot-p> is true, include a MultiBoot-compliant header in the image."
  (when (and (not ignore-dump-count)
	     (= 0 (dump-count *image*)))
    ;; This is a hack to deal with the fact that the first dump won't work
    ;; because the packages aren't properly set up.
    (format t "~&;; Doing initiating dump..")
    (dump-image :path path :multiboot-p multiboot-p :ignore-dump-count t)
    (assert (plusp (dump-count *image*))))
  (let ((load-address (image-start-address *image*)))
    (setf (image-cons-pointer *image*) (- load-address
					  (image-ds-segment-base *image*))
	  (image-address-hash *image*) (make-hash-table :test #'eq)
	  (image-object-hash  *image*) (make-hash-table :test #'eq)
	  (image-multiboot-header *image*) (make-instance 'multiboot-header
					     :header-address 0
					     :load-address 0
					     :load-end-address 0
					     :entry-address 0))
    (assert (= load-address (+ (image-intern-object *image* (image-constant-block *image*))
			       (image-ds-segment-base *image*))))
    (when multiboot-p
      (assert (< (+ (image-intern-object *image* (image-multiboot-header *image*))
		    (sizeof (image-multiboot-header *image*))
		    (- load-address))
		 8192)))
    ;; make the toplevel-funobj
    (unless (image-load-time-funobjs *image*)
      (warn "No top-level funobjs!"))
    (setf (image-load-time-funobjs *image*)
      (stable-sort (copy-list (image-load-time-funobjs *image*)) #'> :key #'third))
    (let* ((toplevel-funobj (make-toplevel-funobj *image*)))
      (setf (image-toplevel-funobj *image*) toplevel-funobj
	    (movitz-constant-block-toplevel-funobj (image-constant-block *image*)) toplevel-funobj)
      (format t "~&;; load-sequence:~%~<~A~>~%" (mapcar #'second (image-load-time-funobjs *image*)))
      (movitz-intern toplevel-funobj)
      (let ((init-code-address (+ (movitz-intern-code-vector (movitz-funobj-code-vector toplevel-funobj))
				  (image-cs-segment-base *image*))))
	(dolist (cf (image-called-functions *image*))
	  (unless (typep (movitz-env-named-function (car cf) nil)
			 'movitz-funobj)
	    (warn "Function ~S is called (in ~S) but not defined." (car cf) (cdr cf))))
	(maphash #'(lambda (symbol function-value)
		     (let ((movitz-symbol (movitz-read symbol)))
		       (if (typep function-value 'movitz-object)
			   ;; (warn "SETTING ~A's funval to ~A"
			 ;; movitz-symbol function-value)
			   (setf (movitz-symbol-function-value movitz-symbol)
			     function-value)
			 #+ignore (warn "fv: ~W" (movitz-macro-expander-function function-value)))))
		 (movitz-environment-function-cells (image-global-environment *image*)))
	(let ((constant-block (image-constant-block *image*)))
	  ;; pull in functions in constant-block
	  (dolist (gcf-name (binary-record-slot-names 'movitz-constant-block :match-tags :global-function))
	    (let* ((gcf-movitz-name (movitz-read (intern (symbol-name gcf-name)
						  ':muerte)))
		   (gcf-funobj (movitz-symbol-function-value gcf-movitz-name)))
	      (setf (slot-value constant-block gcf-name) 0)
	      (cond
	       ((or (not gcf-funobj)
		    (eq 'muerte::unbound gcf-funobj))
		(warn "Global constant function ~S is not defined!" gcf-name))
	       (t (check-type gcf-funobj movitz-funobj)
		  (setf (slot-value constant-block gcf-name)
		    gcf-funobj)))))
	  ;; pull in primitive functions in constant-block
	  (dolist (pf-name (binary-record-slot-names 'movitz-constant-block
						     :match-tags :primitive-function))
	    (setf (slot-value constant-block pf-name)
	      (find-primitive-function (intern (symbol-name pf-name) :muerte))))
	  #+ignore
	  (loop for k being the hash-keys of (movitz-environment-setf-function-names *movitz-global-environment*)
	      using (hash-value v)
	      do (assert (eq (symbol-value v) 'muerte::setf-placeholder))
	      do (when (eq *movitz-nil* (movitz-symbol-function-value (movitz-read v)))
		   (warn "non-used setf: ~S" v)))
	  ;; symbol plists
	  (loop for (symbol plist) on (movitz-environment-plists *movitz-global-environment*) by #'cddr
											   ;; do (warn "sp: ~S ~S" symbol plist)
	      do (let ((x (movitz-read symbol)))
		   (typecase x
		     (movitz-symbol
		      (setf (movitz-plist x)
			(movitz-read (translate-program plist :cl :muerte.cl))))
		     (movitz-nil)
		     (t (warn "not a symbol for plist: ~S has ~S" symbol plist)))))
	  ;; pull in global properties
	  (setf (movitz-constant-block-global-properties constant-block)
	    (movitz-read (nconc (mapcan #'(lambda (var)
					 (list (movitz-read var) (movitz-read (symbol-value var))))
				     (image-compile-time-variables *image*))
			     (list :setf-namespace (movitz-environment-setf-function-names
						    *movitz-global-environment*)
				   :trampoline-funcall%1op (find-primitive-function
							    'muerte::trampoline-funcall%1op)
				   :trampoline-funcall%2op (find-primitive-function
							    'muerte::trampoline-funcall%2op)
				   :packages (make-packages-hash))))))
	(with-binary-file (stream path
				  :check-stream t
				  :direction :output
				  :if-exists :supersede
				  :if-does-not-exist :create)
	  (assert (file-position stream 512) () ; leave room for bootblock.
	    "Couldn't set file-position for ~W." (pathname stream))
	  (let* ((stack-vector (make-instance 'movitz-vector
				 :num-elements #xffff
				 :fill-pointer 0
				 :symbolic-data nil
				 :element-type :u32))
		 (image-start (file-position stream)))
	    (dump-image-core *image* stream) ; dump the kernel proper.
	    ;; make a stack-vector for the root run-time-context
	    (let* ((stack-vector-word
		    (let ((*endian* :little-endian))
		      (write-binary-record stack-vector stream)
		      ;; Intern as _last_ object in image.
		      (movitz-intern stack-vector)))
		   (image-end (file-position stream))
		   (kernel-size (- image-end image-start)))
	      (format t "~&;; Kernel size: ~D octets.~%" kernel-size)
	      (unless (zerop (mod image-end 512)) ; Ensure image is multiple of 512 octets
		(file-position stream (+ image-end (- 511 (mod image-end 512))))
		(write-byte #x0 stream))
	      (format t "~&;; Image file size: ~D octets.~%" image-end)
	      ;; Write simple stage1 bootblock into sector 0..
	      (format t "~&;; Dump count: ~D." (incf (dump-count *image*)))
	      (assert (file-position stream 0))
	      (flet ((global-slot-position (slot-name)
		       (+ 512
			  (image-nil-word *image*)
			  (image-ds-segment-base *image*)
			  (global-constant-offset slot-name)
			  (- load-address))))
		(let ((bootblock (make-bootblock kernel-size
						 load-address
						 init-code-address)))
		  (setf (image-bootblock *image*) bootblock)
		  (write-sequence bootblock stream)
		  (let* ((stack-vector-address (+ (image-nil-word *image*)
						  (global-constant-offset 'stack-vector)
						  (image-ds-segment-base *image*)))
			 (stack-vector-position (- (+ stack-vector-address 512)
						   load-address)))
		    (declare (ignore stack-vector-position))
		    #+ignore(warn "stack-v-pos: ~S => ~S" 
				  stack-vector-position
				  stack-vector-word)
		    (assert (file-position stream (global-slot-position 'stack-vector)
					   #+ignore stack-vector-position))
		    (write-binary 'word stream stack-vector-word)
		    (assert (file-position stream (global-slot-position 'stack-bottom)))
		    (write-binary 'lu32 stream (+ 8 (* 4 4096) ; cushion
						  (- stack-vector-word (tag :other))))
		    (assert (file-position stream (global-slot-position 'stack-top)))
		    (write-binary 'lu32 stream (+ 8 (- stack-vector-word (tag :other))
						  (* 4 (movitz-vector-num-elements stack-vector)))))
		  (if (not multiboot-p)
		      (format t "~&;; No multiboot header.")
		    ;; Update multiboot header, symbolic and in the file..
		    (let* ((mb (image-multiboot-header *image*))
			   (mb-address (+ (movitz-intern mb) (image-ds-segment-base *image*)))
			   (mb-file-position (- (+ mb-address 512) load-address)))
		      (when (< load-address #x100000)
			(warn "Multiboot load-address #x~x is below the 1MB mark."
			      load-address))
		      (when (> (+ mb-file-position (sizeof mb)) 8192)
			(warn "Multiboot header at position ~D is above the 8KB mark."))
		      (assert (file-position stream mb-file-position) ()
			"Couldn't set file-position for ~W to ~W."
			(pathname stream)
			mb-file-position)
		      ;; (format t "~&;; Multiboot load-address: #x~X." load-address)
		      (setf (header-address mb) mb-address
			    (load-address mb) load-address
			    (load-end-address mb) (+ load-address kernel-size)
			    (bss-end-address mb) (+ load-address kernel-size)
			    (entry-address mb) init-code-address)
		      (write-binary-record mb stream)))))))))))
  (values))

(defun dump-image-core (image stream)
  (let ((*endian* :little-endian)
	(*record-all-funobjs* nil)
	(symbols-size 0)
	(conses-size 0)
	(funobjs-size 0)
	(code-vectors-size 0)
	(strings-size 0)
	(simple-vectors-size 0)
	(total-size 0)
	(symbols-numof 0)
	(gensyms-numof 0)
	(conses-numof 0)
	(funobjs-numof 0)
	(code-vectors-numof 0)
	(strings-numof 0)
	(simple-vectors-numof 0)
	(file-start-position (file-position stream))
	(pad-size 0))
    (declare (special *record-all-funobjs*))
    (loop for p upfrom (- (image-start-address image) (image-ds-segment-base image)) by 8
	until (>= p (image-cons-pointer image))
	summing
	  (let ((obj (image-memref image p)))
	    (cond
	     ((not obj) 0)
	     (t (let ((new-pos (+ p file-start-position
				  (- (image-start-address image)
				     (image-ds-segment-base image)))))
		  (incf pad-size (- new-pos (file-position stream)))
		  (file-position stream new-pos))
		;; (warn "Dump at address #x~X, filepos #x~X: ~A" p (file-position stream) obj)
		(let ((old-pos (file-position stream))
		      (write-size (write-binary-record obj stream)))
		  (incf total-size write-size)
		  (typecase obj
		    (movitz-vector
		     (case (movitz-vector-element-type obj)
		       (:character (incf strings-numof)
				   (incf strings-size write-size))
		       (:any-t (incf simple-vectors-numof)
			       (incf simple-vectors-size write-size))
		       (:u8 (when (member :code-vector-p (movitz-vector-flags obj))
			      (incf code-vectors-numof)
			      (incf code-vectors-size write-size)))))
		    (movitz-funobj (incf funobjs-numof)
				(incf funobjs-size write-size))
		    (movitz-symbol (incf symbols-numof)
				(incf symbols-size write-size)
				(when (movitz-eql *movitz-nil* (movitz-symbol-package obj))
				  (incf gensyms-numof)))
		    (movitz-cons (incf conses-numof)
			      (incf conses-size write-size)))
		  (assert (= write-size (sizeof obj) (- (file-position stream) old-pos)) ()
		    "Inconsistent write-size(~D)/sizeof(~D)/file-position delta(~D) ~
                       for object ~S."
		    write-size (sizeof obj) (- (file-position stream) old-pos) obj)
		  write-size))))
	finally
	  (let ((total-size (file-position stream))
		(sum (+ symbols-size conses-size funobjs-size strings-size
			simple-vectors-size code-vectors-size pad-size)))
	    (format t "~&;;~%;; ~D symbols (~D gensyms) (~,1F KB ~~ ~,1F%), ~D conses (~,1F KB ~~ ~,1F%),
;; ~D funobjs (~,1F KB ~~ ~,1F%), ~D strings (~,1F KB ~~ ~,1F%),
;; ~D simple-vectors (~,1F KB ~~ ~,1F%), ~D code-vectors (~,1F KB ~~ ~,1F%).
;; ~,1F KB (~,1F%) of padding.
;; In sum this accounts for ~,1F%, or ~D bytes.~%;;~%"
		    symbols-numof gensyms-numof
		    (/ symbols-size 1024) (/ (* symbols-size 100) total-size)
		    conses-numof (/ conses-size 1024) (/ (* conses-size 100) total-size)
		    funobjs-numof (/ funobjs-size 1024) (/ (* funobjs-size 100) total-size)
		    strings-numof (/ strings-size 1024) (/ (* strings-size 100) total-size)
		    simple-vectors-numof (/ simple-vectors-size 1024) (/ (* simple-vectors-size 100) total-size)
		    code-vectors-numof (/ code-vectors-size 1024) (/ (* code-vectors-size 100) total-size)
		    (/ pad-size 1024) (/ (* pad-size 100) total-size)
		    (/ (* sum 100) total-size)
		    sum)))))

(defun intern-movitz-symbol (name)
  #+ignore (assert (or (not (symbol-package name))
		       (eq (symbol-package name)
			   (find-package :keyword))
		       (string= (string :muerte.)
				(package-name (symbol-package name))
				:end2 (min 5 (length (package-name (symbol-package name))))))
	       (name)
	     "Trying to movitz-intern a symbol not in a Movitz package: ~S" name)
  (or (gethash name (image-oblist *image*))
      (let ((symbol (make-movitz-symbol name)))
	(when (get name :setf-placeholder)
	  (setf (movitz-symbol-flags symbol) '(:setf-placeholder)
		(movitz-symbol-value symbol) (movitz-read (get name :setf-placeholder))))
	(setf (gethash name (image-oblist *image*)) symbol)
	(when (symbol-package name)
	  (let ((p (gethash (symbol-package name) (image-read-map-hash *image*))))
	    (when p
	      (setf (movitz-symbol-package symbol) p))))
	(when (or (eq 'muerte.cl:t name)
		  (keywordp (translate-program name :muerte.cl :cl)))
	  (pushnew :constant-variable (movitz-symbol-flags symbol))
	  (setf (movitz-symbol-value symbol)
	    (movitz-read (translate-program (symbol-value (translate-program name :muerte.cl :cl))
					 :cl :muerte.cl))))
	symbol)))

(defun make-packages-hash (&optional (*image* *image*))
  (let ((lisp-to-movitz-package (make-hash-table :test #'eq))
	(packages-hash (make-hash-table :test #'equal :size 23)))
    (labels ((movitz-package-name (name &optional symbol)
	       (declare (ignore symbol))
	       (cond
		((string= (string :keyword) name)
		 name)
		((and (< 7 (length name))
		      (string= (string 'muerte.) name :end2 7))
		 (subseq name 7))
		(t #+ignore (warn "Package ~S ~@[for symbol ~S ~]is not a Movitz package."
				  name symbol)
		   name)))
	     (ensure-package (package-name lisp-package)
	       (setf (gethash lisp-package lisp-to-movitz-package)
		 (or (gethash package-name packages-hash nil)
		     (let ((p (funcall 'muerte::make-package-object
				       :name package-name
				       :shadowing-symbols-list (package-shadowing-symbols lisp-package)
				       :external-symbols (make-hash-table :test #'equal)
				       :internal-symbols (make-hash-table :test #'equal))))
		       (setf (gethash package-name packages-hash) p)
		       (setf (slot-value p 'muerte::use-list)
			 (mapcar #'(lambda (up) 
				     (ensure-package (movitz-package-name (package-name up)) up))
				 (package-use-list lisp-package)))
		       p)))))
      (let ((cl-package (ensure-package (symbol-name :common-lisp)
					(find-package :muerte.common-lisp))))
	(setf (gethash "NIL" (slot-value cl-package 'muerte::external-symbols))
	  nil))
      (loop for symbol being the hash-key of (image-oblist *image*)
	  as lisp-package = (symbol-package symbol)
	  as package-name = (and lisp-package
				 (movitz-package-name (package-name lisp-package) symbol))
	  when package-name
	  do (let* ((movitz-package (ensure-package package-name lisp-package)))
	       (multiple-value-bind (symbol status)
		   (find-symbol (symbol-name symbol) (symbol-package symbol))
		 (ecase status
		   (:internal
		    (setf (gethash (symbol-name symbol)
				   (slot-value movitz-package 'muerte::internal-symbols))
		      symbol))
		   (:external
		    ;; (warn "putting external ~S in ~S" symbol package-name)
		    (setf (gethash (symbol-name symbol)
				   (slot-value movitz-package 'muerte::external-symbols))
		      symbol))
		   (:inherited
		    (warn "inherited symbol: ~S" symbol))))))
;;;    (warn "PA: ~S" packages-hash)
      (let ((movitz-packages (movitz-read packages-hash)))
	(maphash (lambda (lisp-package movitz-package)
		   (setf (gethash lisp-package (image-read-map-hash *image*))
		     (movitz-read movitz-package)))
		 lisp-to-movitz-package)
	(setf (slot-value (movitz-constant-block-null-symbol (image-constant-block *image*))
			  'package)
	  (movitz-read (ensure-package (string :common-lisp) :muerte.common-lisp)))
	(loop for symbol being the hash-key of (image-oblist *image*)
	    as lisp-package = (symbol-package symbol)
	    as package-name = (and lisp-package
				   (movitz-package-name (package-name lisp-package) symbol))
;;;	    do (when (string= symbol :method)
;;;		 (warn "XXXX ~S ~S ~S" symbol lisp-package package-name))
	    when package-name
	    do (let* ((movitz-package (ensure-package package-name lisp-package)))
		 (setf (movitz-symbol-package (movitz-read symbol))
		   (movitz-read movitz-package))))
	movitz-packages))))


(defun constant-block-find-slot (offset)
  "Return the name of the constant-block slot located at offset."
  (dolist (slot-name (bt:binary-record-slot-names 'movitz-constant-block))
    (when (= offset (bt:slot-offset 'movitz-constant-block slot-name))
      (return slot-name))))

(defun comment-instruction (instruction funobj pc)
  "Return a list of strings that comments on INSTRUCTION."
  (loop for operand in (ia-x86::instruction-operands instruction)
      when (and (typep operand 'ia-x86::operand-indirect-register)
		(eq 'ia-x86::edi (ia-x86::operand-register operand))
		(not (ia-x86::operand-register2 operand))
		(= 1 (ia-x86::operand-scale operand))
		(constant-block-find-slot (ia-x86::operand-offset operand))
		(not (typep instruction 'ia-x86-instr::lea)))
      collect (format nil "<Global slot ~A>" 
		      (constant-block-find-slot (ia-x86::operand-offset operand)))
      when (and (typep operand 'ia-x86::operand-indirect-register)
		(eq 'ia-x86::edi (ia-x86::operand-register operand))
		(typep instruction 'ia-x86-instr::lea)
		(or (not (ia-x86::operand-register2 operand))
		    (eq 'ia-x86::edi (ia-x86::operand-register2 operand))))
      collect (let ((x (+ (* (ia-x86::operand-scale operand)
			     (image-nil-word *image*))
			  (ia-x86::operand-offset operand)
			  (ecase (ia-x86::operand-register2 operand)
			    (ia-x86::edi (image-nil-word *image*))
			    ((nil) 0)))))
		(case (ldb (byte 3 0) x)
		  (#.(tag :character)
		     (format nil "Immediate ~D (char ~S)"
			     x (code-char (ldb (byte 8 8) x))))
		  (#.(mapcar 'tag +fixnum-tags+)
		   (format nil "Immediate ~D (fixnum ~D #x~X)"
			   x
			   (truncate x +movitz-fixnum-factor+)
			   (truncate x +movitz-fixnum-factor+)))
		  (t (format nil "Immediate ~D" x))))
      when (and funobj
		(typep operand 'ia-x86::operand-indirect-register)
		(eq 'ia-x86::esi (ia-x86::operand-register operand))
		(member (ia-x86::operand-register2 operand) '(ia-x86::edi nil))
		(= 1 (ia-x86::operand-scale operand))
		#+ignore (= (mod (slot-offset 'movitz-funobj 'constant0) 4)
			    (mod (ia-x86::operand-offset operand) 4))
		(<= 12 (ia-x86::operand-offset operand)))
      collect (format nil "~A"
		      (nth (truncate (- (+ (ia-x86::operand-offset operand)
					   (if (eq 'ia-x86::edi (ia-x86::operand-register2 operand))
					       (image-nil-word *image*)
					     0))
					(slot-offset 'movitz-funobj 'constant0))
				     4)
			   (movitz-funobj-const-list funobj)))
      when (and funobj
		(typep operand 'ia-x86::operand-indirect-register)
		(eq 'ia-x86::esi (ia-x86::operand-register2 operand))
		(eq 'ia-x86::edi (ia-x86::operand-register operand))
		(<= 12 (ia-x86::operand-offset operand)))
      collect (format nil "~A" (nth (truncate (- (+ (ia-x86::operand-offset operand)
						    (* (ia-x86::operand-scale operand)
						       (image-nil-word *image*)))
						 (slot-offset 'movitz-funobj 'constant0))
					      4)
				    (movitz-funobj-const-list funobj)))
      when (and funobj (typep operand 'ia-x86::operand-rel-pointer))
      collect (let* ((x (+ pc
			   (imagpart (ia-x86::instruction-original-datum instruction))
			   (length (ia-x86:instruction-prefixes instruction))
			   (ia-x86::operand-offset operand)))
		     (label (car (find x (movitz-funobj-symtab funobj) :key #'cdr))))
		(if label
		    (format nil "branch to ~S at ~D" label x)
		  (format nil "branch to ~D" x)))
      when (and (typep operand 'ia-x86::operand-immediate)
		(<= 256 (ia-x86::operand-value operand))
		(= (tag :character) (mod (ia-x86::operand-value operand) 256)))
      collect (format nil "#\\~C" (code-char (truncate (ia-x86::operand-value operand) 256)))
      when (and (typep operand 'ia-x86::operand-immediate)
		(zerop (mod (ia-x86::operand-value operand)
			    +movitz-fixnum-factor+)))
      collect (format nil "#x~X" (truncate (ia-x86::operand-value operand)
					   +movitz-fixnum-factor+))))
		  
(defun movitz-disassemble (name  &rest args &key ((:image *image*) *image*) &allow-other-keys)
  (let* ((funobj (movitz-env-named-function name)))
    (declare (special *image*))
    (apply #'movitz-disassemble-funobj funobj :name name args)))

(defun movitz-assembly (name &optional (*image* *image*))
  (let* ((funobj (movitz-env-named-function name)))
    (declare (special *image*))
    (format t "~{~A~%~}" (movitz-funobj-symbolic-code funobj))))

(defun movitz-disassemble-toplevel (module)
  (let ((funobj (car (find module (image-load-time-funobjs *image*) :key #'second))))
    (assert funobj (module)
      "No load funobj found for module ~S." module)
    (movitz-disassemble-funobj funobj :name module)))

(defparameter *recursive-disassemble-remember-funobjs* nil)

(defun movitz-disassemble-funobj (funobj &key (name (movitz-funobj-name funobj)) ((:image *image*) *image*)
					   (recursive t))
  (let* ((code-vector (movitz-funobj-code-vector funobj))
	 (code (map 'vector #'identity
		    (movitz-vector-symbolic-data code-vector)))
	 (code-position 0)
	 (entry-points (map 'list #'identity (subseq code (movitz-vector-fill-pointer code-vector)))))
    (format t "~&;; Movitz Disassembly of ~A:~@[
;;  Constants: ~A~]
~:{~4D: ~16<~{ ~2,'0X~}~;~> ~A~@[ ;~{ ~A~}~]~%~}"
	    (movitz-print (or (movitz-funobj-name funobj) name))
	    (movitz-funobj-const-list funobj)
	    (loop
		for pc = 0 then code-position
		for instruction = (ia-x86:decode-read-octet
				   #'(lambda ()
				       (when (< code-position
						(movitz-vector-fill-pointer code-vector))
					 (prog1
					     (aref code code-position)
					   (incf code-position)))))
		for cbyte = (and instruction
				 (ia-x86::instruction-original-datum instruction))
		until (null instruction)
		when (let ((x (find pc (movitz-funobj-symtab funobj) :key #'cdr)))
		       (when x (list pc (list (format nil "  ~S" (car x))) "" nil)))
		collect it
		when (some (lambda (x)
			     (and (plusp pc) (= pc (* x +code-vector-entry-factor+))))
			   entry-points)
		collect (list pc nil
			      (format nil "  => Entry-point for ~D arguments <="
				      (1+ (position-if (lambda (x)
							 (= pc (* x +code-vector-entry-factor+)))
						       entry-points)))
			      nil)
		collect (list pc
			      (ia-x86::cbyte-to-octet-list cbyte)
			      instruction
			      (comment-instruction instruction funobj pc)))))
  (when recursive
    (let ((*recursive-disassemble-remember-funobjs*
	   (cons funobj *recursive-disassemble-remember-funobjs*)))
      (loop for x in (movitz-funobj-const-list funobj)
	  do (when (and (typep x '(and movitz-funobj (not movitz-funobj-standard-gf)))
			(not (member x *recursive-disassemble-remember-funobjs*)))
	       (push x *recursive-disassemble-remember-funobjs*)
	       (terpri)
	       (movitz-disassemble-funobj x)))))
  (values))

(defun movitz-disassemble-primitive (name &optional (*image* *image*))
  (let* ((code-vector (cond
		       ((slot-exists-p (image-constant-block *image*) name)
			(slot-value (image-constant-block *image*) name))
		       (t (movitz-symbol-value (movitz-read name)))))
	 (code (map 'vector #'identity
		    (movitz-vector-symbolic-data code-vector)))
	 (code-position 0))
    (format t "~&;; Movitz disassembly of ~S:
~:{~4D: ~16<~{ ~2,'0X~}~;~> ~A~@[ ;~{ ~A~}~]~%~}"
	    name
	    (loop
		for pc = 0 then code-position
		for instruction = (ia-x86:decode-read-octet
				   #'(lambda ()
				       (when (< code-position (length code))
					 (prog1
					     (aref code code-position)
					   (incf code-position)))))
		until (null instruction)
		for cbyte = (ia-x86::instruction-original-datum instruction)
		collect (list pc
			      (ia-x86::cbyte-to-octet-list cbyte)
			      instruction
			      (comment-instruction instruction nil pc))))
    (values)))

(defmethod image-read-intern-constant ((*image* symbolic-image) expr)
  (typecase expr
    (string
     (or (gethash expr (image-string-constants *image*))
	 (setf (gethash expr (image-string-constants *image*))
	   (make-movitz-string expr))))
    (cons
     (or (gethash expr (image-cons-constants *image*))
	 (setf (gethash expr (image-cons-constants *image*))
	    (if (eq '#0=#:error (ignore-errors (when (not (list-length expr)) '#0#)))
		(multiple-value-bind (unfolded-expr cdr-index)
		    (unfold-circular-list expr)
		  (let ((result (movitz-read unfolded-expr)))
		    (setf (movitz-last-cdr result)
		      (movitz-nthcdr cdr-index result))
		    result))
	      (make-movitz-cons (movitz-read (car expr))
			     (movitz-read (cdr expr)))))))
    (t (movitz-read expr))))

;;; "Reader"

(defmethod image-lisp-to-movitz-object ((image symbolic-image) lisp-object)
  (gethash lisp-object (image-read-map-hash image)))

(defmethod (setf image-lisp-to-movitz-object) (movitz-object (image symbolic-image) lisp-object)
  (setf (gethash movitz-object (image-inverse-read-map-hash image)) lisp-object
	(gethash lisp-object (image-read-map-hash image)) movitz-object))

(defmacro with-movitz-read-context (options &body body)
  (declare (ignore options))
  `(let ((*movitz-reader-clean-map* (if (boundp '*movitz-reader-clean-map*)
				     *movitz-reader-clean-map*
				   (make-hash-table :test #'eq))))
     (declare (special *movitz-reader-clean-map*))
     ,@body))

(defun movitz-read (expr)
  "Map native lisp data to movitz-objects. Makes sure that when two EXPR are EQ, ~@
   the Movitz objects are also EQ, under the same image."
  (declare (optimize (debug 3) (speed 0)))
  (with-movitz-read-context ()
    (when (typep expr 'movitz-object)
      (return-from movitz-read expr))
    (or
     (let ((old-object (image-lisp-to-movitz-object *image* expr)))
       (when (and old-object (not (gethash old-object *movitz-reader-clean-map*)))
	 (update-movitz-object old-object expr)
	 (setf (gethash old-object *movitz-reader-clean-map*) t))
       old-object)
     (setf (image-lisp-to-movitz-object *image* expr)
       (etypecase expr
	 (null *movitz-nil*)
	 ((member t) (movitz-read 'muerte.cl:t))
	 (symbol (intern-movitz-symbol expr))
	 (string (image-read-intern-constant *image* expr))
	 (integer (make-movitz-fixnum expr))
	 (character (make-movitz-character expr))
	 (vector (make-movitz-vector (length expr)
				  :initial-contents (map 'vector #'movitz-read expr)))
	 (cons
	  (image-read-intern-constant *image* expr)
	  #+ignore (if (eq '#0=#:error (ignore-errors (when (not (list-length expr)) '#0#)))
		       (multiple-value-bind (unfolded-expr cdr-index)
			   (unfold-circular-list expr)
			 (let ((result (movitz-read unfolded-expr)))
			   (setf (movitz-last-cdr result)
			     (movitz-nthcdr cdr-index result))
			   result))
		     (make-movitz-cons (movitz-read (car expr))
				    (movitz-read (cdr expr)))))
	 (hash-table
	  (make-movitz-hash-table expr))
	 (structure-object
	  (let ((slot-descriptions (gethash (type-of expr)
					    (image-struct-slot-descriptions *image*)
					    nil)))
	    (unless slot-descriptions
	      (error "Don't know how to movitz-read struct: ~S" expr))
	    (let ((movitz-object (make-instance 'movitz-struct
				:name (movitz-read (type-of expr))
				:length (length slot-descriptions))))
	      (setf (image-lisp-to-movitz-object *image* expr) movitz-object)
	      (setf (slot-value movitz-object 'slot-values)
		(mapcar #'(lambda (slot) (movitz-read (slot-value expr slot)))
			slot-descriptions))
	      movitz-object))))))))

;;;

(defun movitz-make-upload-form (object &optional (quotep t))
  "Not completed."
  (typecase object
    ((or movitz-nil null) "()")
    (cons
     (format nil "(list~{ ~A~})"
	     (mapcar #'movitz-make-upload-form object)))
    (movitz-cons
     (format nil "(list~{ ~A~})"
	     (mapcar #'movitz-make-upload-form (movitz-print object))))
    (movitz-funobj
     (format nil "(internal:make-funobj :name ~A :constants ~A :code-vector ~A)"
	     (movitz-make-upload-form (movitz-funobj-name object))
	     (movitz-make-upload-form (movitz-funobj-const-list object))
	     (movitz-print (movitz-funobj-code-vector object))))
    (movitz-symbol
     (let ((package (movitz-symbol-package object)))
       (cond
	((eq *movitz-nil* package) 
	 (if (member :setf-placeholder (movitz-symbol-flags object))
	     (format nil "(internal:setf-intern ~A)"
		     (movitz-make-upload-form (movitz-symbol-value object)))
	   (format nil "~:[~;'~]#:~A" quotep (movitz-print object))))
	(t (check-type package movitz-struct)
	   (assert (eq (movitz-struct-name package) (movitz-read 'muerte::package-object)))
	   (let ((package-name (intern (movitz-print (first (movitz-struct-slot-values package))))))
	     (case package-name
	       (keyword (format nil ":~A" (movitz-print object)))
	       (common-lisp (format nil "~:[~;'~]~A" quotep (movitz-print object)))
	       (t (format nil "~:[~;'~]~A:~A" quotep package-name (movitz-print object)))))))))
    (movitz-vector
     (case (movitz-vector-element-type object)
       (:character (format nil "\"~A\"" (movitz-print object)))
       (t (movitz-print object))))
    (t (format nil "~A" (movitz-print object)))))
      

(defun movitz-upload-function (name &optional (destination :bochs) (verbose nil))
  (unless (stringp destination)
    (setf destination
      (ecase destination
	(:kayak "fe80::240:f4ff:fe36:6f02%xl0")
	(:decpc "fe80::240:5ff:fe18:66d7%xl0")
	(:bochs "fe80::240:5ff:fe18:66d8%xl0"))))
  (let ((funobj (movitz-env-symbol-function name))
	(*print-readably* t)
	(*print-pretty* nil)
	(*print-base* 16)
	(*print-radix* nil))
    (let ((command (format nil "(internal:install-function ~A (list~{ ~A~}) ~W)"
			   (movitz-make-upload-form (movitz-read name))
			   (mapcar #'movitz-make-upload-form (movitz-funobj-const-list funobj))
			   (movitz-print (movitz-funobj-code-vector funobj)))))
      (when verbose
	(pprint command) (terpri) (force-output))
      (if destination
	  (excl::run-shell-command (format nil "./udp6-send.py ~A 1 ~S" destination command))
	command))))
	    

;;; "Printer"

(defun movitz-print (expr)
  (etypecase expr
    (integer expr)
    (symbol expr)
    (cons (mapcar #'movitz-print expr))
    ((or movitz-nil movitz-constant-block) nil)
    (movitz-symbol
     (intern (movitz-print (movitz-symbol-name expr))))
    (movitz-string
     (map 'string #'identity
	  (movitz-vector-symbolic-data expr)))
    (movitz-fixnum
     (movitz-fixnum-value expr))
    (movitz-vector
     (map 'vector #'movitz-print (movitz-vector-symbolic-data expr)))
    (movitz-cons
     (cons (movitz-print (movitz-car expr))
	   (movitz-print (movitz-cdr expr))))))

;;;

(defmethod make-toplevel-funobj ((*image* symbolic-image))
  (let ((toplevel-code (loop for (funobj) in (image-load-time-funobjs *image*)
			   collect `(muerte::simple-funcall ,funobj))))
    (make-compiled-funobj 'muerte::toplevel-function ()
			  '((muerte::without-function-prelude))
			  `(muerte.cl:progn
			     (muerte::with-inline-assembly (:returns :nothing)
			       (:cli)

			       (:movw ,(1- (* 8 8)) (:esp -6))
			       (:movl ,(+ (image-ds-segment-base *image*)
					  (image-nil-word *image*)
					  (global-constant-offset 'segment-descriptor-table))
				      :ecx)
			       (:movl :ecx (:esp -4))
			       (:lgdt (:esp -6))

			       ;; Move to new CS
			       (:pushl ,(ash (* 3 8) 0)) ; push segment selector
			       (:call (:pc+ 0)) ; push EIP
			      jmp-base
			       (:subl '(:funcall ,(lambda (base dest)
						    (+ (image-cs-segment-base *image*) (- dest) base))
					
					'jmp-base 'jmp-destination)
				      (:esp))
			       (:jmp-segment (:esp))
			      jmp-destination
			       
			       (:movw ,(* 4 8) :cx)
			       (:movw :cx :ds)
			       (:movw :cx :es)
			       (:movw :cx :ss)
			       (:movw ,(* 2 8) :cx)
			       (:movw :cx :gs) ; global context segment
			       (:movw ,(* 5 8) :cx)
			       (:movw :cx :fs) ; thread context segment

			       (:movl ,(image-nil-word *image*) :edi)
			       (:globally (:movl (:edi (:edi-offset stack-top)) :esp))

			       (:pushl #x37ab7378)
			       (:pushl #x37ab7378)
			       (:pushl 0)
			       (:pushl 0)
			       (:movl :esp :ebp)
			       
			       (:globally (:movl (:edi (:edi-offset toplevel-funobj)) :esi))
			       (:pushl :esi)
			       (:pushl :edi)
			       (:cmpl #x2badb002 :eax)
			       (:jne 'no-multiboot)
			       (:movl ,(movitz-read-and-intern 'muerte::*multiboot-data* 'word)
				      :eax)
			       ;; (:compile-form (:result-mode :eax) 'muerte::*multiboot-data*)
			       ;; (:shll ,+movitz-fixnum-shift+ :ebx)
			       (:movl :ebx (:eax ,(bt:slot-offset 'movitz-symbol 'value)))
			      no-multiboot)
			       			       ;; Check that the stack works..
;;;			       (:pushl #xabbabeef)
;;;			       (:popl :eax)
;;;			       (:cmpl #xabbabeef :eax)
;;;			       (:jne '(:sub-program (stack-doesnt-work)
;;;				       (:movl :ebp :eax)
;;;				       (:movl #xb8020 :ebx)
;;;				       ,@(mkasm-write-word-eax-ebx)
;;;				       (:movl (:edi -1) :eax)
;;;				       (:movl #xb8040 :ebx)
;;;				       ,@(mkasm-write-word-eax-ebx)
;;;				       (:jmp (:pc+ -2)))))

			     ,@toplevel-code
			     (muerte::halt-cpu))
			  nil t)))

(defun mkasm-write-word-eax-ebx ()
  (let ((loop-label (make-symbol "write-word-loop"))
	(l1 (make-symbol "write-word-l1"))
	(l2 (make-symbol "write-word-l2"))
	(l3 (make-symbol "write-word-l3"))
	(l4 (make-symbol "write-word-l4")))
    `(;; (:compile-two-forms (:eax :ebx) ,word ,dest)
      (:movl :eax :edx)

      ;; (:shrl #.los0::+movitz-fixnum-shift+ :ebx)
      (:movb 2 :cl)

      ((:gs-override) :movl #x07000700 (:ebx 0))
      ((:gs-override) :movl #x07000700 (:ebx 4))
      ((:gs-override) :movl #x07000700 (:ebx 8))
      ((:gs-override) :movl #x07000700 (:ebx 12))
      ,loop-label

      (:andl #x0f0f0f0f :eax)
      (:addl #x30303030 :eax)

      (:cmpb #x39 :al) (:jle ',l1) (:addb 7 :al)
      ,l1 ((:gs-override) :movb :al (14 :ebx)) ; 8
      (:cmpb #x39 :ah) (:jle ',l2) (:addb 7 :ah)
      ,l2 ((:gs-override) :movb :ah (10 :ebx)) ; 6

      (:shrl 16 :eax)
      
      (:cmpb #x39 :al) (:jle ',l3) (:addb 7 :al)
      ,l3 ((:gs-override) :movb :al (6 :ebx)) ; 4
      (:cmpb #x39 :ah) (:jle ',l4) (:addb 7 :ah)
      ,l4 ((:gs-override) :movb :ah (2 :ebx)) ; 2

      (:movl :edx :eax)
      (:shrl 4 :eax)
      (:subl 2 :ebx)
      (:decb :cl)
      (:jnz ',loop-label))))
    

;;;
