;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 2001-2004, 
;;;;    Department of Computer Science, University of Troms�, Norway.
;;;; 
;;;;    For distribution policy, see the accompanying file COPYING.
;;;; 
;;;; Filename:      procfs-image.lisp
;;;; Description:   
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Fri Aug 24 11:39:37 2001
;;;;                
;;;; $Id: procfs-image.lisp,v 1.1 2004/01/13 11:04:59 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(in-package movitz)

(defclass procfs-image (stream-image)
  ((pid
    :initarg :pid
    :reader image-pid)
   (procfs-connection
    :initarg :procfs
    :reader procfs-image-connection)))

(defmacro with-procfs-image ((pid
			      &key (procfs-var (gensym))
				   (image-var '*image*)
				   (offset #x811b000))
			     &body body)
  `(let ((pid ,pid))
     (procfs:with-procfs-attached (,procfs-var pid :direction :io)
       (let ((,image-var (make-instance 'procfs-image
			   :pid pid
			   :procfs ,procfs-var
			   :stream (procfs:procfs-connection-mem-stream ,procfs-var)
			   :offset ,offset)))
	 ,@body))))

(defclass bochs-image (procfs-image)
  ((register-set-address
    :initarg :register-set-address
    :reader bochs-image-register-set-address)
   (gdtr-address
    :initarg :gdtr-address
    :reader bochs-image-gdtr-address)
   (sregs-address
    :initarg :sregs-address
    :reader bochs-image-sregs-address)
   (start-address
    :initarg :start-address
    :initform #x100000
    :accessor image-start-address)
   ))

(defun read-alist-file (path)
  (with-open-file (stream path :direction :input)
    (loop for c = (read stream nil '#0=:eof)
	until (eq #0# c)
	when (consp c)
	collect c)))

(defun bochs-parameter (p path)
  (cdr (assoc p (read-alist-file path))))

(defmacro with-bochs-image ((&key (path #p"bochs-parameters")
				  (procfs-var (gensym))
				  (image-var '*image*))
			    &body body)
  `(let ((bt:*endian* :little-endian)
	 (pid (bochs-parameter :pid ,path)))
     (procfs:with-procfs-attached (,procfs-var pid :direction :io)
       (let ((,image-var (make-instance 'bochs-image
			   :pid pid
			   :procfs ,procfs-var
			   :stream (procfs:procfs-connection-mem-stream ,procfs-var)
			   :register-set-address (+ 0 (bochs-parameter :cpu ,path))
			   :offset (bochs-parameter :memory ,path)
			   :sregs-address (bochs-parameter :sregs ,path)
			   :gdtr-address (bochs-parameter :gdtr ,path))))
	 ,@body))))
  

(define-unsigned r32 4 :little-endian)

(define-binary-class bochs-registers ()
  ((eax :binary-type r32)
   (ecx :binary-type r32)
   (edx :binary-type r32)
   (ebx :binary-type r32)
   (esp :binary-type r32)
   (ebp :binary-type r32)
   (esi :binary-type r32)
   (edi :binary-type r32)
   (eip :binary-type r32)))

(defmethod image-register32 ((image bochs-image) register-name)
  (assert (file-position (image-stream image)
			 (bochs-image-register-set-address image)))
  (let ((register-set (read-binary 'bochs-registers (image-stream image))))
    (slot-value register-set (intern register-name :movitz))))

(defun register32 (register-name)
  (image-register32 *image* register-name))

(defmethod report-gdtr ((image bochs-image))
  (assert (file-position (image-stream image)
			 (bochs-image-gdtr-address image)))
  (let* ((*endian* :little-endian)
	 (base (read-binary 'u32 (image-stream image)))
	 (limit (read-binary 'u16 (image-stream image))))
    (format t "~&GDTR: base #x~X, limit #x~X~%" base limit)
    (assert (zerop (mod base 4)) ()
      "Base is not aligned to 16 bytes.")
    (assert (zerop (mod (1+ limit) 8)) ()
      "Limit is not aligned to 8 bytes.")
    (setf (image-stream-position *image*) base)
    (dotimes (i (truncate (1+ limit) 8))
      (format t "Descriptor ~D: ~<~W~>~%" i (read-binary 'code-segment-descriptor (image-stream image))))
    (values)))
    
(defmethod report-segment-registers ((image bochs-image))
  (let* ((*endian* :little-endian))
    (format t "~&Segment registers: ")
    (loop for (reg . address) in (bochs-image-sregs-address image)
	do (assert (file-position (image-stream image) address))
	do (format t "~A: #x~X " reg (read-binary 'u16 (image-stream image)))
	finally (terpri)))
  (values))

(defun current-stack-frame ()
  (image-register32 *image* :ebp))

(defun previous-stack-frame (stack-frame)
  (get-word stack-frame))

(defun stack-frame-funobj (stack-frame)
  (when (zerop (ldb (byte 2 0) stack-frame))
    (let ((x (movitz-word (get-word (- stack-frame 4)))))
      (and (typep x 'movitz-funobj) x))))

(defun stack-frame-return-address (stack-frame)
  (when (zerop (ldb (byte 2 0) stack-frame))
    (get-word (- stack-frame -4))))

(defun backtrace ()
  (format t "~&Backtracing from EIP = #x~X: "
	  (image-register32 *image* :eip))
  ;; (search-image-funobj (image-register32 *image* :eip))
  (format t "~&Current ESI: #x~X.~%"
	  (image-register32 *image* :esi))
  (loop with unknown-counter = 0
      for stack-frame = (current-stack-frame) then (previous-stack-frame stack-frame)
      unless (zerop (mod stack-frame 4))
      do (format t "[#x~8,'0x]" stack-frame)
      and do (loop-finish)
      do (let ((movitz-name (funobj-name (stack-frame-funobj stack-frame))))
	   (typecase movitz-name
	     (null
	      (when (< 10 (incf unknown-counter))
		(return-from backtrace nil))
	      (write-string "?")
	      (let* ((r (stack-frame-return-address stack-frame))
		     (eax (get-word (+ stack-frame 28 8)))
		     (ecx (get-word (+ stack-frame 24 8)))
		     (edi (get-word (+ stack-frame 0 8)))
		     (eip (get-word (+ stack-frame 40 8)))
		     (exception (get-word (+ stack-frame 32 8)))
		     (return (get-word (+ stack-frame 52 8))))
		(when r (format t " (ret #x~X {EAX: #x~X, ECX: #x~X, EDI: #x~X, EIP: #x~X, exception ~D, ret: #x~X})"
				r eax ecx edi eip exception return))))
	     (movitz-symbol
	      (let ((name (movitz-print movitz-name)))
		(write-string (symbol-name name))
		(when (string= name 'toplevel-function)
		  (loop-finish))
		(format t " (#x~X)" (stack-frame-return-address stack-frame))))
	     (t (write (movitz-print movitz-name)))))
      do (format t "~& => "))
  (values))

(defun funobj-name (x)
  (typecase x
    (movitz-funobj
     (movitz-funobj-name x))))

(defun stack-frame (image)
  (do-stack-frame (image-register32 image :ebp) 0))
    
(defun get-word (address &optional physicalp)
  (unless (zerop (ldb (byte 2 0) address))
    (warn "Non-aligned address to GET-WORD: #x~8,'0X." address))
  (setf (image-stream-position *image* physicalp) address)
  (read-binary 'word (image-stream *image*)))

(defun do-stack-frame (frame-address count)
  (warn "Frame ~D: #x~8,'0X" count frame-address)
  (when (< count 10)
    (do-stack-frame (get-word frame-address) (1+ count))))


(defun current-dynamic-context ()
  (slot-value (image-constant-block *image*) 'dynamic-env))

(defun stack-ref-p (pointer)
  (let ((top #xa0000)
	(bottom (image-register32 *image* :esp)))
    (<= bottom pointer top)))

(defun stack-ref (pointer offset index type)
  (assert (stack-ref-p pointer) (pointer)
    "Stack pointer not in range: #x~X" pointer)
  (ecase type
    (:lisp
     (movitz-word (get-word (+ pointer offset (* 4 index)))))
    (:unsigned-byte32
     (values (get-word (+ pointer offset (* 4 index)))))))

(defun dynamic-context-uplink (dynamic-context)
  (stack-ref dynamic-context 12 0 :unsigned-byte32))

(defun dynamic-context-tag (dynamic-context)
  (stack-ref dynamic-context 4 0 :lisp))

(defun load-global-constant (slot-name)
  (slot-value (image-constant-block *image*) slot-name))

(defun image-eq (x y)
  (eql (movitz-intern x) (movitz-intern y)))

(defun print-dynamic-context (&optional (initial-dynamic-context (current-dynamic-context)))
  (loop for dynamic-context = initial-dynamic-context
      then (dynamic-context-uplink dynamic-context)
      while (stack-ref-p dynamic-context)
      do (let ((tag (dynamic-context-tag dynamic-context)))
	   (cond
	    ((image-eq tag (load-global-constant 'unbound-value))
	     (format t "~&#x~X: name: ~A => value: ~A"
		     dynamic-context
		     (stack-ref dynamic-context 0 0 :lisp)
		     (stack-ref dynamic-context 8 0 :lisp)))
	    (t (format t "~&#x~X:  tag: #x~X [name #x~X, val #x~X]"
		       dynamic-context
		       (stack-ref dynamic-context 4 0 :unsigned-byte32)
		       (stack-ref dynamic-context 0 0 :unsigned-byte32)
		       (stack-ref dynamic-context 8 0 :unsigned-byte32)))))
      finally (format t "~&Last uplink: #x~X~%" dynamic-context)
	      (values)))


#+allegro
(top-level:alias ("bochs" 0) (&rest forms)
  (with-bochs-image ()
    (with-simple-restart (continue "Exit this bochs session [pid=~D]" (image-pid *image*))
      (if forms
	  (let ((x (multiple-value-list (eval (cons 'progn forms)))))
	    (format t "~{~&~W~}" x)
	    (values-list x))
	(invoke-debugger "Established connection to Bochs [pid=~D]."
			 (image-pid *image*))))))