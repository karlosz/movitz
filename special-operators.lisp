;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 20012000, 2002-2004,
;;;;    Department of Computer Science, University of Troms�, Norway
;;;; 
;;;; Filename:      special-operators.lisp
;;;; Description:   Compilation of internal special operators.
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Fri Nov 24 16:22:59 2000
;;;;                
;;;; $Id: special-operators.lisp,v 1.1 2004/01/13 11:04:59 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(in-package movitz)

(defun ccc-result-to-returns (result-mode)
  (check-type result-mode keyword)
  (case result-mode
    (:ignore :nothing)
    (:function :multiple-values)
    (t result-mode)))

(defun make-compiled-cond-clause (clause clause-num last-clause-p exit-label funobj env result-mode)
  "Return three values: The code for a cond clause,
a boolean value indicating whether the clause's test was constantly true,
The set of modified bindings."
  (assert (not (atom clause)))
  (let* ((clause-modifies nil)
	 (test-form (car clause))
	 (then-forms (cdr clause)))
    (cond
     ((null then-forms)
      (compiler-values-bind (&code test-code &returns test-returns)
	  (compiler-call #'compile-form
	    :modify-accumulate clause-modifies
	    :result-mode (case (operator result-mode)
			   (:boolean-branch-on-false
			    (if last-clause-p
				result-mode
			      (cons :boolean-branch-on-true
				    exit-label)))
			   (:boolean-branch-on-true
			    result-mode)
			   (:ignore
			    (cons :boolean-branch-on-true
				  exit-label))
			   (:push
			    (if last-clause-p
				:push
			      :eax))
			   (#.+multiple-value-result-modes+
			    :eax)
			   (t result-mode))
	    :form test-form
	    :funobj funobj
	    :env env)
	(assert (not (null test-code)) (clause) "null test-code!")
	(values (ecase (operator test-returns)
		  ((:boolean-branch-on-true
		    :boolean-branch-on-false)
		   test-code)
		  (:push
		   (assert last-clause-p)
		   test-code)
		  ((:multiple-values :eax :ebx :ecx :edx)
;;;		   (when (eq result-mode :function)
;;;		     (warn "test-returns: ~S" test-returns))
		   (let ((singlify (when (member result-mode +multiple-value-result-modes+)
				     '((:clc)))))
		     (append test-code
			     (cond
			      ((not last-clause-p)
			       (append
				`((:cmpl :edi ,(single-value-register (operator test-returns))))
				singlify
				(when (eq :push result-mode)
				  `((:pushl ,(single-value-register (operator test-returns)))))
				`((:jne ',exit-label))))
			      (t singlify))))))
		nil)))
     ((not (null then-forms))
      (let ((skip-label (gensym (format nil "cond-skip-~D-" clause-num))))
	(compiler-values-bind (&code test-code)
	    (multiple-value-bind (test-result-mode)
		(cond
		 ((and last-clause-p
		       (eq (operator result-mode)
			   :boolean-branch-on-false))
		  (cons :boolean-branch-on-false
			(cdr result-mode)))
		 (t (cons :boolean-branch-on-false
			  skip-label)))
	      (compiler-call #'compile-form
		:result-mode test-result-mode
		:modify-accumulate clause-modifies
		:form test-form
		:funobj funobj
		:env env))
	  (compiler-values-bind (&code then-code &returns then-returns)
	      (compiler-call #'compile-form
		:form (cons 'muerte.cl::progn then-forms)
		:modify-accumulate clause-modifies
		:funobj funobj
		:env env
		:result-mode result-mode)
	    (let ((constantly-true-p (null test-code)))
	      (values (append test-code
			      then-code
			      (unless (or last-clause-p (eq then-returns :non-local-exit))
				`((:jmp ',exit-label)))
			      (unless constantly-true-p
				(list skip-label)))
		      constantly-true-p
		      clause-modifies)))))))))

(defun chose-joined-returns-and-result (result-mode)
  "From a result-mode, determine a joined result-mode (for several branches),
and the correspondig returns mode (secondary value)."
  (let ((joined-result-mode (case (operator result-mode)
			      (:values :multiple-values)
			      ((:ignore :function :multiple-values :eax :ebx :ecx :edx
				:boolean-branch-on-false :boolean-branch-on-true)
			       result-mode)
			      (t :eax))))
    (values joined-result-mode
	    (ecase (operator joined-result-mode)
	      (:ignore :nothing)
	      (:function :multiple-values)
	      ((:multiple-values :eax :push :eax :ebx :ecx :edx
		:boolean-branch-on-true :boolean-branch-on-false)
	       joined-result-mode)))))

(define-special-operator compiled-cond
    (&form form &funobj funobj &env env &result-mode result-mode)
  (let ((clauses (cdr form)))
    (let* ((cond-modifies nil)
	   (cond-exit-label (gensym "cond-exit-"))
	   (cond-result-mode (case (operator result-mode)
			       (:values :multiple-values)
			       ((:ignore :function :multiple-values :eax :ebx :ecx :edx
				 :boolean-branch-on-false :boolean-branch-on-true)
				result-mode)
			       (t :eax)))
	   (cond-returns (ecase (operator cond-result-mode)
			   (:ignore :nothing)
			   (:function :multiple-values)
			   ((:multiple-values :eax :push :eax :ebx :ecx :edx
			     :boolean-branch-on-true :boolean-branch-on-false)
			    cond-result-mode)))
	   (only-control-p (member (operator cond-result-mode)
				   '(:ignore
				     :boolean-branch-on-true
				     :boolean-branch-on-false))))
      (loop for clause in clauses
	  for clause-num upfrom 0
	  with last-clause-num = (1- (length clauses))
	  as (clause-code constantly-true-p clause-modifies) =
	    (multiple-value-list (make-compiled-cond-clause clause
							    clause-num
							    (and only-control-p
								 (= clause-num last-clause-num))
							    cond-exit-label funobj env cond-result-mode))
	  append clause-code into cond-code
	  do (setf cond-modifies
	       (modifies-union cond-modifies clause-modifies))
	  when constantly-true-p
	  do (return (compiler-values ()
		       :returns cond-returns
		       :modifies cond-modifies
		       :code (append cond-code
				     (list cond-exit-label))))
	  finally
	    (return (compiler-values ()
		      :returns cond-returns
		      :modifies cond-modifies
		      :code (append cond-code
				    ;; no test succeeded => nil
				    (unless only-control-p
;;;				      (warn "doing default nil..")
				      (compiler-call #'compile-form
					:form nil
					:funobj funobj
					:env env
					:top-level-p nil
					:result-mode cond-result-mode))
				    (list cond-exit-label))))))))


(define-special-operator compiled-case (&all all &form form &result-mode result-mode)
  (destructuring-bind (keyform &rest clauses)
      (cdr form)
    #+ignore
    (let ((cases (loop for (clause . nil) in clauses
		     append (if (consp clause)
				clause
			      (unless (member clause '(nil muerte.cl:t muerte.cl:otherwise))
				(list clause))))))
      (warn "case clauses:~%~S" cases))
    (compiler-values-bind (&code key-code &returns key-returns)
	(compiler-call #'compile-form-unprotected
	  :result-mode :eax
	  :forward all
	  :form keyform)
      (multiple-value-bind (case-result-mode case-returns)
	  (chose-joined-returns-and-result result-mode)
	(let ((key-reg (accept-register-mode key-returns)))
	  (flet ((otherwise-clause-p (x)
		   (member (car x) '(muerte.cl:t muerte.cl:otherwise)))
		 (make-first-check (key then-label then-code exit-label)
		   `((:load-constant ,key ,key-reg :op :cmpl)
		     (:je '(:sub-program (,then-label)
			    ,@then-code
			    (:jmp ',exit-label))))))
	    (cond
	     ((otherwise-clause-p (first clauses))
	      (compiler-call #'compile-implicit-progn
		:forward all
		:form (rest (first clauses))))
	     (t (compiler-values ()
		  :returns case-returns
		  :code (append (make-result-and-returns-glue key-reg key-returns key-code)
				(loop with exit-label = (gensym "case-exit-")
				    for clause-head on clauses
				    as clause = (first clause-head)
				    as keys =  (first clause)
				    as then-forms = (rest clause)
				    as then-label = (gensym "case-then-")
				    as then-code = (compiler-call #'compile-form
						     :result-mode case-result-mode
						     :forward all
						     :form `(muerte.cl:progn ,@then-forms))
				    if (otherwise-clause-p clause)
				    do (assert (endp (rest clause-head)) ()
					 "Case's otherwise clause must be the last clause.")
				    and append then-code
				    else if (atom keys)
				    append (make-first-check keys then-label then-code exit-label)
				    else append (make-first-check (first keys) then-label
								  then-code exit-label)
				    and append (loop for key in (rest keys)
						   append `((:load-constant ,key ,key-reg :op :cmpl)
							    (:je ',then-label)))
				    if (endp (rest clause-head))
				    append (append (unless (otherwise-clause-p clause)
						     (compiler-call #'compile-form
						       :result-mode case-result-mode
						       :forward all
						       :form nil))
						   (list exit-label)))))))))))))
					     
		  
	     
(define-special-operator make-named-function (&form form &env env)
  (destructuring-bind (name formals declarations docstring body)
      (cdr form)
    (declare (ignore docstring))
    (handler-bind (#+ignore ((or error warning) (lambda (c)
					 (declare (ignore c))
					 (format *error-output* "~&;; In function ~S:~&" name))))
      (let* ((*compiling-function-name* name)
	     (funobj (make-compiled-funobj name formals declarations body env nil)))
	(setf (movitz-funobj-symbolic-name funobj) name)
	(setf (movitz-env-named-function name) funobj))))
  (compiler-values ()))

(define-special-operator make-primitive-function (&form form &env env)
  (destructuring-bind (name docstring body)
      (cdr form)
    (handler-bind (((or warning error) (lambda (c)
					 (declare (ignore c))
					 (format *error-output* "~&;; In primitive function ~S:" name))))
      (let ((code-vector (make-compiled-primitive body env nil docstring)))
	(setf (movitz-symbol-value (movitz-read name)) code-vector)
	(compiler-values ())))))

(define-special-operator define-prototyped-function (&form form)
  (destructuring-bind (function-name proto-name &rest parameters)
      (cdr form)
    (let* ((funobj-proto (movitz-env-named-function proto-name))
	   (code-vector (movitz-funobj-code-vector funobj-proto))
	   (funobj (make-instance 'movitz-funobj
		     :name (movitz-read function-name)
		     :code-vector code-vector
		     :lambda-list (movitz-funobj-lambda-list funobj-proto)
		     :num-constants (movitz-funobj-num-constants funobj-proto)
		     :num-jumpers (movitz-funobj-num-jumpers funobj-proto)
		     :jumpers-map (movitz-funobj-jumpers-map funobj-proto)
		     :symbolic-code (when (slot-boundp funobj-proto 'symbolic-code)
				      (movitz-funobj-symbolic-code funobj-proto))
		     :const-list (let ((c (copy-list (movitz-funobj-const-list funobj-proto))))
				   (loop for (lisp-parameter value) in parameters
				       as parameter = (movitz-read lisp-parameter)
				       do (assert (member parameter c) ()
					    "~S is not a function prototype parameter for ~S. ~
The valid parameters are~{ ~S~}."
					    parameter proto-name
					    (mapcar #'movitz-print (movitz-funobj-const-list funobj-proto)))
				       do (setf (car (member parameter c)) (movitz-read value)))
				   c))))
      (setf (movitz-funobj-symbolic-name funobj) function-name)
      (setf (movitz-env-named-function function-name) funobj)
      (compiler-values ()))))

(define-special-operator make-prototyped-function (&all forward &form form)
  (destructuring-bind (function-name proto-name &rest parameters)
      (cdr form)
    (let* ((funobj-proto (movitz-env-named-function proto-name))
	   (code-vector (movitz-funobj-code-vector funobj-proto))
	   (funobj (make-instance 'movitz-funobj
		     :name (movitz-read function-name)
		     :code-vector code-vector
		     :lambda-list (movitz-funobj-lambda-list funobj-proto)
		     :num-constants (movitz-funobj-num-constants funobj-proto)
		     :symbolic-code (when (slot-boundp funobj-proto 'symbolic-code)
				      (movitz-funobj-symbolic-code funobj-proto))
		     :const-list (let ((c (copy-list (movitz-funobj-const-list funobj-proto))))
				   (loop for (lisp-parameter value) in parameters
				       as parameter = (movitz-read lisp-parameter)
				       do (assert (member parameter c) ()
					    "~S is not a function prototype parameter for ~S. ~
The valid parameters are~{ ~S~}."
					    parameter proto-name
					    (mapcar #'movitz-print (movitz-funobj-const-list funobj-proto)))
				       do (setf (car (member parameter c)) (movitz-read value)))
				   c))))
      (compiler-call #'compile-self-evaluating
	:form funobj
	:forward forward))))

(define-special-operator define-setf-expander-compile-time (&form form)
  (destructuring-bind (access-fn lambda-list macro-body)
      (cdr form)
    (multiple-value-bind (wholevar envvar reqvars optionals restvar keyvars auxvars)
	(decode-macro-lambda-list lambda-list)
      (let ((cl-lambda-list (translate-program `(,@reqvars
						 ,@(when optionals '(&optional)) ,@optionals
						 ,@(when restvar `(&rest ,restvar))
						 ,@(when keyvars '(&key)) ,@keyvars
						 ,@(when auxvars '(&aux)) ,@auxvars)
					       :muerte.cl :cl))
	    (cl-macro-body (translate-program macro-body :muerte.cl :cl)))
	(multiple-value-bind (cl-body declarations doc-string)
	    (parse-docstring-declarations-and-body cl-macro-body 'cl:declare)
	  (declare (ignore doc-string))
	  (setf (movitz-env-get access-fn :setf-expander nil)
	    (let ((form-formal (or wholevar (gensym)))
		  (env-formal (or envvar (gensym))))
	      (if (null cl-lambda-list)
		  `(lambda (,form-formal ,env-formal)
		     (declare ,@declarations)
		     (translate-program (block ,access-fn ,@cl-body) :cl :muerte.cl))
		`(lambda (,form-formal ,env-formal)
		   (declare ,@declarations)
		   (destructuring-bind ,cl-lambda-list
		       (translate-program (rest ,form-formal) :muerte.cl :cl)
		     (values-list
		      (translate-program (multiple-value-list (block ,access-fn ,@cl-body))
					 :cl :muerte.cl)))))))))))
  (compiler-values ()))

(define-special-operator muerte::defmacro-compile-time (&form form)
  (destructuring-bind (name lambda-list macro-body)
      (cdr form)
    (check-type name symbol "a macro name")
    (multiple-value-bind (wholevar envvar reqvars optionals restvar keyvars auxvars)
	(decode-macro-lambda-list lambda-list)
      (let ((expander-name (make-symbol (format nil "~A-macro" name)))
	    (cl-lambda-list (translate-program `(,@reqvars
						 ,@(when optionals '(&optional)) ,@optionals
						 ,@(when restvar `(&rest ,restvar))
						 ,@(when keyvars '(&key)) ,@keyvars
						 ,@(when auxvars '(&aux)) ,@auxvars)
					       :muerte.cl :cl))
	    (cl-macro-body (translate-program macro-body :muerte.cl :cl)))
	(when (member name (image-called-functions *image*) :key #'first)
	  #+ignore (warn "Macro ~S defined after being called as function (in ~S)."
			 name
			 (cdr (find name (image-called-functions *image*) :key #'first))))
	(multiple-value-bind (cl-body declarations doc-string)
	    (parse-docstring-declarations-and-body cl-macro-body 'cl:declare)
	  (declare (ignore doc-string))
;;;	(warn "defmacro ~S: ~S" name cl-body)
	  (let ((expander-lambda
		 (let ((form-formal (or wholevar (gensym)))
		       (env-formal (or envvar (gensym))))
		   (if (null cl-lambda-list)
		       `(lambda (,form-formal ,env-formal)
			  (declare (ignorable ,form-formal ,env-formal))
			  (declare ,@declarations)
			  (translate-program  (block ,name ,@cl-body) :cl :muerte.cl))
		     `(lambda (,form-formal ,env-formal)
			(declare (ignorable ,form-formal ,env-formal))
			(destructuring-bind ,cl-lambda-list
			    (translate-program (rest ,form-formal) :muerte.cl :cl)
			  (declare ,@declarations)
			  (translate-program  (block ,name ,@cl-body) :cl :muerte.cl)))))))
	    (setf (movitz-macro-function name)
	      (if *compiler-compile-macro-expanders*
		  (compile expander-name expander-lambda)
		expander-lambda)))))))
  (compiler-values ()))

(define-special-operator muerte::define-compiler-macro-compile-time (&form form)
  ;; This scheme doesn't quite cut it..
  (destructuring-bind (name lambda-list doc-dec-body)
      (cdr form)
    (multiple-value-bind (body declarations)
	(parse-docstring-declarations-and-body doc-dec-body)
      (let ((operator-name (or (and (setf-name name)
				    (movitz-env-setf-operator-name (setf-name name)))
			       name)))
	(multiple-value-bind (wholevar envvar reqvars optionals restvar keyvars auxvars)
	    (decode-macro-lambda-list lambda-list)
	  (let ((cl-lambda-list (translate-program `(,@reqvars
						     ,@(when optionals '(&optional)) ,@optionals
						     ,@(when restvar `(&rest ,restvar))
						     ,@(when keyvars '(&key)) ,@keyvars
						     ,@(when auxvars '(&aux)) ,@auxvars)
						   :muerte.cl :cl))
		(cl-body (translate-program body :muerte.cl :cl))
		(declarations (translate-program declarations :muerte.cl :cl))
		(form-formal (or wholevar (gensym)))
		(env-formal (or envvar (gensym)))
		(expansion-var (gensym)))
	    (when (member operator-name (image-called-functions *image*) :key #'first)
	      (warn "Compiler-macro ~S defined after being called as function (in ~S)"
		    operator-name
		    (cdr (find operator-name (image-called-functions *image*) :key #'first))))
	    (let ((expander
		   `(lambda (,form-formal ,env-formal)
		      (declare (ignorable ,env-formal))
		      (destructuring-bind ,cl-lambda-list
			  (translate-program (rest ,form-formal) :muerte.cl :cl)
			(declare ,@declarations)
			(let ((,expansion-var (block ,operator-name ,@cl-body)))
			  (if (eq ,form-formal ,expansion-var)
			      ,form-formal ; declined
			    (translate-program ,expansion-var :cl :muerte.cl)))))))
	      (setf (movitz-compiler-macro-function operator-name nil)
		(if *compiler-compile-macro-expanders*
		    (compile (make-symbol (format nil "~A-compiler-macro" name)) expander)
		  expander))))))))
  (compiler-values ()))

(define-special-operator muerte::with-inline-assembly-case
    (&all forward &form form &funobj funobj &env env &result-mode result-mode)
  (destructuring-bind (global-options &body inline-asm-cases)
      (cdr form)
    (destructuring-bind (&key (side-effects t) ((:type global-type)))
	global-options
      (let ((modifies ()))
	(loop for case-spec in inline-asm-cases
	    finally (error "Found no inline-assembly-case matching ~S." result-mode)
	    do (destructuring-bind ((matching-result-modes &optional (returns :same)
							   &key labels (type global-type))
				    &body inline-asm)
		   (cdr case-spec)
		 (when (eq returns :same)
		   (setf returns result-mode))
		 (when (flet ((match (matching-result-mode)
				(or (eq 'muerte.cl::t matching-result-mode)
				    (eq t matching-result-mode)
				    (eq (operator result-mode) matching-result-mode)
				    (and (eq :register matching-result-mode)
					 (member result-mode '(:eax ebx ecx edx :single-value))))))
			 (if (symbolp matching-result-modes)
			     (match matching-result-modes)
			   (find-if #'match matching-result-modes)))
		   (case returns
		     (:register
		      (setf returns (case result-mode
				      ((:eax :ebx :ecx :edx) result-mode)
				      (t :eax)))))
		   (unless type
		     (setf type
		       (ecase (operator returns)
			 ((:nothing) nil)
			 ((:eax :ebx :ecx :edx) t)
			 (#.+boolean-modes+ t)
			 ((:boolean-branch-on-false
			   :boolean-branch-on-true) t)
			 ((:multiple-values) '(values &rest t)))))
		   (return
		     (let ((amenv (make-assembly-macro-environment))) ; XXX this is really wasteful..
		       (setf (assembly-macro-expander :branch-when amenv)
			 #'(lambda (expr)
			     (destructuring-bind (boolean-mode)
				 (cdr expr)
			       (ecase (operator result-mode)
				 ((:boolean-branch-on-true :boolean-branch-on-false)
				  (list (make-branch-on-boolean boolean-mode (operands result-mode)
								:invert nil)))))))
		       (setf (assembly-macro-expander :compile-form amenv)
			 #'(lambda (expr)
			     (destructuring-bind ((&key ((:result-mode sub-result-mode))) sub-form)
				 (cdr expr)
			       (case sub-result-mode
				 (:register
				  (setf sub-result-mode returns))
				 (:same
				  (setf sub-result-mode result-mode)))
			       (assert sub-result-mode (sub-result-mode)
				 "Assembly :COMPILE-FORM directive doesn't provide a result-mode: ~S"
				 expr)
			       (compiler-values-bind (&code sub-code &functional-p sub-functional-p
						      &modifies sub-modifies)
				   (compiler-call #'compile-form
				     :defaults forward
				     :form sub-form
				     :result-mode sub-result-mode)
				 ;; if a sub-compile has side-effects, then the entire
				 ;; with-inline-assembly form does too.
				 (unless sub-functional-p
				   (setq side-effects t))
				 (setf modifies (modifies-union modifies sub-modifies))
				 sub-code))))
		       (setf (assembly-macro-expander :result-register amenv)
			 #'(lambda (expr)
			     (assert (= 1 (length expr)))
			     (assert (member returns '(:eax :ebx :ecx :edx)))
			     (list returns)))
		       (setf (assembly-macro-expander :result-register-low8 amenv)
			 #'(lambda (expr)
			     (assert (= 1 (length expr)))
			     (assert (member returns '(:eax :ebx :ecx :edx)))
			     (list (register32-to-low8 returns))))
		       (setf (assembly-macro-expander :compile-arglist amenv)
			 #'(lambda (expr)
			     (destructuring-bind (() &rest arg-forms)
				 (cdr expr)
			       (setq side-effects t)
			       (make-compiled-argument-forms arg-forms funobj env))))
		       (setf (assembly-macro-expander :compile-two-forms amenv)
			 #'(lambda (expr)
			     (destructuring-bind ((reg1 reg2) form1 form2)
				 (cdr expr)
			       (multiple-value-bind (code sub-functional-p sub-modifies)
				   (make-compiled-two-forms-into-registers form1 reg1 form2 reg2
									   funobj env)
				 (unless sub-functional-p
				   (setq side-effects t))
				 (setq modifies (modifies-union modifies sub-modifies))
				 code))))
;;;		       #+ignore
		       (setf (assembly-macro-expander :call-global-constant amenv)
			 #'(lambda (expr)
			     (destructuring-bind (name)
				 (cdr expr)
			       `((:globally (:call (:edi (:edi-offset ,name))))))))
;;;		       #+ignore
;;;		       (setf (assembly-macro-expander :store-global-constant amenv)
;;;			 #'(lambda (expr)
;;;			     (assert side-effects ()
;;;			       "Can't do :store-global-constant when :side-effects nil is declared.")
;;;			     (destructuring-bind (name source &key thread-local)
;;;				 (cdr expr)
;;;			       (let ((pf (if thread-local '((:fs-override)))))
;;;				 `((,@pf :movl ,source
;;;					 ,(make-indirect-reference :edi (global-constant-offset name))))))))
;;;		       (setf (assembly-macro-expander :load-global-constant amenv)
;;;			 #'(lambda (expr)
;;;			     (destructuring-bind (name destination &key thread-local)
;;;				 (cdr expr)
;;;			       (let ((pf (if thread-local '((:fs-override)))))
;;;				 `((,@pf :movl ,(make-indirect-reference :edi (global-constant-offset name))
;;;					,destination))))))
		       (setf (assembly-macro-expander :warn amenv)
			 #'(lambda (expr)
			     (apply #'warn (cdr expr))
			     nil))
		       (setf (assembly-macro-expander :lexical-store amenv)
			 (lambda (expr)
			   (destructuring-bind (var reg &key (type t))
			       (cdr expr)
			     `((:store-lexical ,(movitz-binding var env) ,reg :type ,type)))))
;;;		       (setf (assembly-macro-expander :locally amenv)
;;;			 (lambda (expr)
;;;			   (destructuring-bind (sub-instr)
;;;			       (cdr expr)
;;;			     (assembly-macroexpand (list (cond
;;;							  ((atom sub-instr)
;;;							   sub-instr)
;;;							  ((consp (car sub-instr))
;;;							   (list* (append *compiler-local-segment-prefix*
;;;									  (car sub-instr))
;;;								  (cdr sub-instr)))
;;;							  (t (list* *compiler-local-segment-prefix*
;;;								    sub-instr))))
;;;						   amenv))))
;;;		       (setf (assembly-macro-expander :globally amenv)
;;;			 (lambda (expr)
;;;			   (destructuring-bind (sub-instr)
;;;			       (cdr expr)
;;;			     (assembly-macroexpand (list (cond
;;;							  ((atom sub-instr)
;;;							   sub-instr)
;;;							  ((consp (car sub-instr))
;;;							   (list* (append *compiler-global-segment-prefix*
;;;									  (car sub-instr))
;;;								  (cdr sub-instr)))
;;;							  (t (list* *compiler-global-segment-prefix*
;;;								    sub-instr))))
;;;						   amenv))))
;;;		       (setf (assembly-macro-expander :edi-offset amenv)
;;;			 (lambda (expr)
;;;			   (destructuring-bind (name)
;;;			       (cdr expr)
;;;			     (list (global-constant-offset name)))))
		       (let ((code (assembly-macroexpand inline-asm amenv)))
			 (assert (not (and (not side-effects)
					   (tree-search code '(:store-lexical))))
			     ()
			   "Inline assembly is declared side-effects-free, but contains :store-lexical.")
			 (when labels
			   (setf code (subst (gensym (format nil "~A-" (first labels)))
					     (first labels)
					     code))
			   (dolist (label (rest labels))
			     (setf code (nsubst (gensym (format nil "~A-" label))
						label
						code))))
			 (compiler-values ()
			   :code code
			   :returns returns
			   :type type
			   :modifies modifies
			   :functional-p (not side-effects))))))))))))


(define-special-operator muerte::declaim-compile-time (&form form &top-level-p top-level-p)
  (unless top-level-p
    (error "DECLAIM not at top-level."))
  (let ((declaration-specifiers (cdr form)))
    (movitz-env-load-declarations declaration-specifiers *movitz-global-environment* :declaim))
  (compiler-values ()))

(define-special-operator call-internal (&form form)
  (destructuring-bind (if-name &optional argument)
      (cdr form)
    (assert (not argument))
    (compiler-values ()
      :code `(,@(when argument
		  `((:load-lexical ,argument :eax)))
		(:call (:edi ,(slot-offset 'movitz-constant-block if-name))))
      :returns :nothing)))

(define-special-operator inlined-not (&all forward &form form &result-mode result-mode)
  (assert (= 2 (length form)))
  (let ((x (second form)))
    (if (eq result-mode :ignore)
	(compiler-call #'compile-form-unprotected
	  :forward forward
	  :form x)
      (multiple-value-bind (not-result-mode result-mode-inverted-p)
	  (cond
	   ((or (member (operator result-mode) +boolean-modes+)
		(member (operator result-mode) '(:boolean-branch-on-false
						 :boolean-branch-on-true)))
	    (values (complement-boolean-result-mode result-mode)
		    t))
	   ((member (operator result-mode) +multiple-value-result-modes+)
	    (values :eax nil))
	   ((member (operator result-mode) '(:push))
	    (values :eax nil))
	   (t (values result-mode nil)))
	(compiler-values-bind (&all not-values &returns not-returns &code not-code)
	    (compiler-call #'compile-form-unprotected
	      :defaults forward
	      :form x
	      :result-mode not-result-mode)
	  (setf (not-values :producer) (list :not (not-values :producer)))
	  ;; (warn "res: ~S" result-mode-inverted-p)
	  (cond
	   ((and result-mode-inverted-p
		 (eql not-result-mode not-returns))
	    ;; Inversion by result-mode ok.
	    (compiler-values (not-values)
	      :returns result-mode))
	   (result-mode-inverted-p
	    ;; (warn "Not done: ~S/~S/~S." result-mode not-result-mode not-returns)
	    (multiple-value-bind (code)
		(make-result-and-returns-glue not-result-mode not-returns not-code)
	      (compiler-values (not-values)
		:returns result-mode
		:code code)))
	   ((not result-mode-inverted-p)
	    ;; We must invert returns-mode
	      (case (operator not-returns)
	      (#.(append +boolean-modes+ '(:boolean-branch-on-true :boolean-branch-on-false))
		 (compiler-values (not-values)
		   :returns (complement-boolean-result-mode not-returns)))
	      ((:eax :function :multiple-values :ebx :edx)
	       (case result-mode
		 ((:eax :ebx :ecx :edx :function :multiple-values)
		  (compiler-values (not-values)
		    :code (append (not-values :code)
				  `((:cmpl :edi ,(single-value-register not-returns))
				    (:sbbl :ecx :ecx)
				    (:cmpl ,(1+ (image-nil-word *image*))
					   ,(single-value-register not-returns))
				    (:adcl 0 :ecx)))
		    :returns '(:boolean-ecx 1 0)))
		 (t (compiler-values (not-values)
		      :code (append (not-values :code)
				    `((:cmpl :edi ,(single-value-register not-returns))))
		      :returns :boolean-zf=1))))
	      ((:eax :function :multiple-values :ebx :ecx :edx)
	       (compiler-values (not-values)
		 :code (append (not-values :code)
			       `((:cmpl :edi ,(single-value-register not-returns))))
		 :returns :boolean-zf=1)) ; TRUE iff result equal to :edi/NIL.
	      (otherwise
	       (warn "unable to deal inteligently with inlined-NOT not-returns: ~S for ~S from ~S"
		     not-returns not-result-mode (not-values :producer))
	       (let ((label (make-symbol "not-label")))
		 (compiler-values (not-values)
		   :returns :eax
		   :code (append (make-result-and-returns-glue :eax not-returns (not-values :code))
				 `((:cmpl :edi :eax)
				   (:movl :edi :eax)
				   (:jne ',label)
				   (:globally (:movl (:edi (:edi-offset t-symbol)) :eax))
				   ,label)))))))))))))

(define-special-operator muerte::with-progn-results
    (&all forward &form form &top-level-p top-level-p &result-mode result-mode)
  (destructuring-bind (buried-result-modes &body body)
      (cdr form)
    (assert (< (length buried-result-modes) (length body)) ()
      "WITH-PROGN-RESULTS must have fewer result-modes than body elements: ~S" form)
    (loop with returns-mode = :nothing
	with no-side-effects-p = t
	with modifies = nil
	for sub-form on body
	as sub-form-result-mode = buried-result-modes
	then (or (cdr sub-form-result-mode)
		 sub-form-result-mode)
	as current-result-mode = (if (endp (cdr sub-form))
				     ;; all but the last form have
				     ;; result-mode as declared
				     result-mode
				   (car sub-form-result-mode))
	as last-form-p = (endp (cdr sub-form))
				 ;; do (warn "progn rm: ~S" (car sub-form-result-mode))
	appending
	  (compiler-values-bind (&code code &returns sub-returns-mode
				 &functional-p no-sub-side-effects-p
				 &modifies sub-modifies)
	      (compiler-call (if last-form-p
				 #'compile-form-unprotected
			       #'compile-form)
		:defaults forward
		:form (car sub-form)
		:top-level-p top-level-p
		:result-mode current-result-mode)
	    (unless no-sub-side-effects-p
	      (setf no-side-effects-p nil))
	    (setq modifies (modifies-union modifies sub-modifies))
	    (when last-form-p
	      ;; (warn "progn rm: ~S form: ~S" sub-returns-mode (car sub-form))
	      (setf returns-mode sub-returns-mode))
	    (if (and no-sub-side-effects-p (eq current-result-mode :ignore))
		nil
	      code))
	into progn-code
	finally (return (compiler-values ()
			  :code progn-code
			  :returns returns-mode
			  :modifies modifies
			  :functional-p no-side-effects-p)))))

(define-special-operator muerte::simple-funcall (&form form)
  (destructuring-bind (apply-funobj)
      (cdr form)
    (compiler-values ()
      :returns :multiple-values
      :functional-p nil
      :code `((:load-constant ,apply-funobj :esi) ; put function funobj in ESI
	      (:xorl :ecx :ecx)		; number of arguments
					; call new ESI's code-vector
	      (:call (:esi ,(slot-offset 'movitz-funobj 'code-vector)))))))

(define-special-operator muerte::compiled-nth-value (&all all &form form &env env &result-mode result-mode)
  (destructuring-bind (n-form subform)
      (cdr form)
    (cond
     ((movitz-constantp n-form)
      (let ((n (eval-form n-form env)))
	(check-type n (integer 0 *))
	(compiler-values-bind (&code subform-code &returns subform-returns)
	    (compiler-call #'compile-form-unprotected
	      :forward all
	      :result-mode :multiple-values
	      :form subform)
	  (if (not (eq subform-returns :multiple-values))
	      ;; single-value result
	      (case n
		(0 (compiler-values ()
		     :code subform-code
		     :returns subform-returns))
		(t (compiler-call #'compile-implicit-progn
		     :forward all
		     :form `(,subform nil))))
	    ;; multiple-value result
	    (case n
	      (0 (compiler-call #'compile-form-unprotected
		   :forward all
		   :result-mode result-mode
		   :form `(muerte.cl:values ,subform)))
	      (1 (compiler-values ()
		   :returns :ebx
		   :code (append subform-code
				 (with-labels (nth-value (done no-secondary))
				   `((:jnc '(:sub-program (,no-secondary)
					     (:movl :edi :ebx)
					     (:jmp ',done)))
				     (:cmpl 2 :ecx)
				     (:jb ',no-secondary)
				     ,done)))))
	      (t (compiler-values ()
		   :returns :eax
		   :code (append subform-code
				 (with-labels (nth-value (done no-value))
				   `((:jnc '(:sub-program (,no-value)
					     (:movl :edi :eax)
					     (:jmp ',done)))
				     (:cmpl ,(1+ n) :ecx)
				     (:jb ',no-value)
				     (:locally (:movl (:edi (:edi-offset values ,(* 4 (- n 2))))
						      :eax))
				     ,done))))))))))
     (t (error "non-constant nth-values not yet implemented.")))))
	      

(define-special-operator muerte::with-cloak
    (&all all &result-mode result-mode &form form &env env &funobj funobj)
  "Compile sub-forms such that they execute ``invisibly'', i.e. have no impact
on the current result."
  (destructuring-bind ((&optional (cover-returns :nothing) cover-code (cover-modifies t)
				  (cover-type '(values &rest t)))
		       &body cloaked-forms)
      (cdr form)
    (assert (or cover-type (eq cover-returns :nothing)))
    (let ((modifies cover-modifies))
      (cond
       ((null cloaked-forms)
	(compiler-values ()
	  :code cover-code
	  :modifies modifies
	  :type cover-type
	  :returns cover-returns))
       ((or (eq :nothing cover-returns)
	    (eq :ignore result-mode))
	(let* ((code (append cover-code
			     (loop for cloaked-form in cloaked-forms
				 appending
				   (compiler-values-bind (&code code &modifies sub-modifies)
				       (compiler-call #'compile-form-unprotected
					 :forward all
					 :form cloaked-form
					 :result-mode :ignore)
				     (setf modifies (modifies-union modifies sub-modifies))
				     code)))))
	  (compiler-values ()
	    :code code
	    :type nil
	    :modifies modifies
	    :returns :nothing)))
       (t (let* ((cloaked-env (make-instance 'with-things-on-stack-env :uplink env :funobj funobj))
		 (cloaked-code (loop for cloaked-form in cloaked-forms
				   append (compiler-values-bind (&code code &modifies sub-modifies)
					      (compiler-call #'compile-form-unprotected
						:env cloaked-env
						:defaults all
						:form cloaked-form
						:result-mode :ignore)
					    (setf modifies (modifies-union modifies sub-modifies))
					    code))))
	    (cond
	     ((member cloaked-code
		      '(() ((:cld)) ((:std))) ; simple programs that don't interfere with current-result.
		      :test #'equal)
	      (compiler-values ()
		:returns cover-returns
		:type cover-type
		:modifies modifies
		:code (append cover-code cloaked-code)))
	     ((and (eq :multiple-values cover-returns)
		   (member result-mode '(:function :multiple-values))
		   (type-specifier-num-values cover-type)
		   (loop for i from 0 below (type-specifier-num-values cover-type)
		       always (type-specifier-singleton (type-specifier-nth-value i cover-type))))
	      ;; We cover a known set of values, so no need to push anything.
	      (let ((value-forms
		     (loop for i from 0 below (type-specifier-num-values cover-type)
			 collect
			   (cons 'muerte.cl:quote
				 (type-specifier-singleton
				  (type-specifier-nth-value i cover-type))))))
		(compiler-values ()
		:returns :multiple-values
		:type cover-type
		:code (append cover-code
			      cloaked-code
			      (compiler-call #'compile-form
				:defaults all
				:result-mode :multiple-values
				:form `(muerte.cl:values ,@value-forms))))))
	     ((and (eq :multiple-values cover-returns)
		   (member result-mode '(:function :multiple-values))
		   (type-specifier-num-values cover-type))
	      (when (loop for i from 0 below (type-specifier-num-values cover-type)
			always (type-specifier-singleton (type-specifier-nth-value i cover-type)))
		(warn "Covering only constants: ~S" cover-type))
	      ;; We know the number of values to cover..
	      (let ((num-values (type-specifier-num-values cover-type)))
		;; (warn "Cunningly covering ~D values.." num-values)
		(setf (stack-used cloaked-env) num-values)
		(compiler-values ()
		  :returns :multiple-values
		  :type cover-type
		  :code (append cover-code
				(when (<= 1 num-values)
				  '((:locally (:pushl :eax))))
				(when (<= 2 num-values)
				  '((:locally (:pushl :ebx))))
				(loop for i from 0 below (- num-values 2)
				    collect
				      `(:locally (:pushl (:edi ,(+ (global-constant-offset 'values)
								   (* 4 i))))))
				cloaked-code
				(when (<= 3 num-values)
				  `((:locally (:movl ,(- num-values 2)
						     (:edi (:edi-offset num-values))))))
				(loop for i downfrom (- num-values 2 1) to 0
				    collect
				      `(:locally (:popl (:edi ,(+ (global-constant-offset 'values)
								  (* 4 i))))))
				(when (<= 2 num-values)
				  '((:popl :ebx)))
				(when (<= 1 num-values)
				  '((:popl :eax)))
				(case num-values
				  (1 '((:clc)))
				  (t (append (make-immediate-move num-values :ecx)
					     '((:stc)))))))))
	     ((and (eq :multiple-values cover-returns)
		   (member result-mode '(:function :multiple-values)))
	      (when (type-specifier-num-values cover-type)
		(warn "covering ~D values: ~S." 
		      (type-specifier-num-values cover-type)
		      cover-type))
	      ;; we need a full-fledged m-v-prog1, i.e to save all values of first-form.
	      ;; (lexically) unknown amount of stack is used.
	      (setf (stack-used cloaked-env) t)
	      (compiler-values ()
		:returns :multiple-values
		:modifies modifies
		:type cover-type
		:code (append cover-code
			      `((:globally (:call (:edi (:edi-offset push-current-values))))
				(:pushl :ecx))
			      cloaked-code
			      `((:popl :ecx)
				(:globally (:call (:edi (:edi-offset pop-current-values))))))))
	     (t ;; just put the (singular) result of form1 on the stack..
	      (when (not (typep cover-returns 'keyword))
		;; if it's a (non-modified) lexical-binding, we can do better..
		(warn "Covering non-register ~S" cover-returns))
	      (when (type-specifier-singleton (type-specifier-primary cover-type))
		(warn "Covering constant ~S"
		      (type-specifier-singleton cover-type)))  
	      (let ((protected-register (case cover-returns
					  ((:ebx :ecx :edx) cover-returns)
					  (t :eax))))
		(when (>= 2 (length cloaked-code))
		  (warn "simple-cloaking for ~S: ~{~&~S~}" cover-returns cloaked-code))
		(setf (stack-used cloaked-env) 1)
		(compiler-values ()
		  :returns protected-register
		  :modifies modifies
		  :type cover-type
		  :code (append cover-code
				(make-result-and-returns-glue protected-register cover-returns)
				`((:pushl ,protected-register))
				;; evaluate each rest-form, discarding results
				cloaked-code
				;; pop the result back
				`((:popl ,protected-register)))))))))))))

(define-special-operator muerte::dynamic-unwind (&form form)
  (let ((unwind-count (second form)))
    (check-type unwind-count (integer 0 *))
    (if (zerop unwind-count)
	(compiler-values ())
      (compiler-values ()
	:returns :nothing
	:code (append (make-immediate-move unwind-count :ecx)
		      `((:globally (:call (:edi (:edi-offset dynamic-unwind))))))))))

(define-special-operator muerte::with-local-env (&all all &form form)
  (destructuring-bind ((local-env) sub-form)
      (cdr form)
    (compiler-call #'compile-form-unprotected
      :forward all
      :env local-env
      :form sub-form)))

(define-special-operator muerte::+%2op (&all all &form form &env env &result-mode result-mode)
  (assert (not (eq :boolean result-mode)) ()
    "Boolean result-mode for +%2op makes no sense.")
  (destructuring-bind (term1 term2)
      (cdr form)
    (flet ((compile-constant-add (constant-term term-form)
	     (compiler-values-bind (&code term2-code &returns term2-returns &type term2-type
				    &functional-p term2-functional-p &modifies term2-modifies)
		 (compiler-call #'compile-form-unprotected
		   :result-mode (case result-mode
				  ((:eax :ebx :ecx :edx)
				   result-mode)
				  (t :eax))
		   :defaults all
		   :form term-form)
	       (assert term2-type)
	       (let ((term2-type (type-specifier-primary term2-type)))
		 (case term2-returns
		   (:untagged-fixnum-eax
		    (case result-mode
		      (:untagged-fixnum-eax
		       (compiler-values ()
			 :returns :untagged-fixnum-eax
			 :functional-p term2-functional-p
			 :modifies term2-modifies
			 :code (append term2-code
				       `((:addl ,constant-term :eax))
				       (unless (< #x-10000 constant-term #x10000)
					 '((:into))))))
		      (t (let ((result-register (accept-register-mode result-mode)))
			   ;; (warn "XX")
			   (compiler-values ()
			     :returns result-register
			     :modifies term2-modifies
			     :functional-p term2-functional-p
			     :code (append term2-code
					   `((:leal ((:eax ,+movitz-fixnum-factor+)
						     ,(* +movitz-fixnum-factor+ constant-term))
						    ,result-register))))))))
		   (t (multiple-value-bind (new-load-term-code add-result-mode)
			  (make-result-and-returns-glue (accept-register-mode term2-returns)
							term2-returns
							term2-code)
			(let ((add-register (single-value-register add-result-mode))
			      (label (gensym "not-integer-")))
			  (compiler-values ()
			    :returns add-register
			    :functional-p term2-functional-p
			    :modifies term2-modifies
			    :code (append
				   new-load-term-code
				   (unless nil #+ignore (subtypep (translate-program term2-type :muerte.cl :cl)
								  `(integer ,+movitz-most-negative-fixnum+
									    ,+movitz-most-positive-fixnum+))
				     `((:testb ,+movitz-fixnum-zmask+
					       ,(register32-to-low8 add-register))
				       (:jnz '(:sub-program (,label) (:int 107) (:jmp (:pc+ -4))))))
				   `((:addl ,(* constant-term +movitz-fixnum-factor+) ,add-register))
				   (unless nil #+ignore (subtypep (translate-program term2-type :muerte.cl :cl)
								  `(integer ,(+ +movitz-most-negative-fixnum+
										constant-term)
									    ,(+ +movitz-most-positive-fixnum+
										constant-term)))
				     '((:into)))))))))))))
      (cond
       ((and (movitz-constantp term1 env)
	     (movitz-constantp term2 env))
	(compiler-call #'compile-self-evaluating
	  :forward all
	  :form (+ (eval-form term1 env)
		   (eval-form term2 env))))
       ((and (movitz-constantp term1 env)	; first operand zero?
	     (zerop (eval-form term1 env)))
	(compiler-call #'compile-form-unprotected
	  :forward all
	  :form term2))			; (+ 0 x) => x
       ((and (movitz-constantp term2 env)	; second operand zero?
	     (zerop (eval-form term2 env)))
	(compiler-call #'compile-form-unprotected
	  :forward all
	  :form term1))			; (+ x 0) => x
       ((movitz-constantp term1 env)
	(let ((constant-term1 (eval-form term1 env)))
	  (check-type constant-term1 (signed-byte 30))
	  (compile-constant-add constant-term1 term2)))
       ((movitz-constantp term2 env)
	(let ((constant-term2 (eval-form term2 env)))
	  (check-type constant-term2 (signed-byte 30))
	  (compile-constant-add constant-term2 term1)))
       (t (compiler-call #'compile-form-unprotected
	    :forward all
	    :form `(muerte::with-inline-assembly (:returns :eax :side-effects nil)
		     (:compile-two-forms (:ebx :eax) ,term1 ,term2)
		     (:addl :ebx :eax)
		     (:into))))))))

(define-special-operator muerte::include (&form form)
  (let ((*require-dependency-chain* (and (boundp '*require-dependency-chain*)
					 *require-dependency-chain*)))
    (declare (special *require-dependency-chain*))
    (destructuring-bind (module-name &optional path-spec)
	(cdr form)
      (declare (ignore path-spec))
      (push module-name *require-dependency-chain*)
      (when (member module-name (cdr *require-dependency-chain*))
	(error "Circular Movitz module dependency chain: ~S"
	       (reverse (subseq *require-dependency-chain* 0
				(1+ (position  module-name *require-dependency-chain* :start 1))))))
      (let ((require-path (movitz-module-path form)))
	(movitz-compile-file-internal require-path))))
  (compiler-values ()))

;;;

(define-special-operator muerte::do-result-mode-case (&all all &result-mode result-mode &form form)
  (loop for (cases . then-forms) in (cddr form)
      do (when (or (eq cases 'muerte.cl::t)
		   (and (eq cases :plural)
			(member result-mode +multiple-value-result-modes+))
		   (and (eq cases :booleans)
			(member (result-mode-type result-mode) '(:boolean-branch-on-false :boolean-branch-on-true)))
		   (if (atom cases)
		       (eq cases (result-mode-type result-mode))
		     (member (result-mode-type result-mode) cases)))
	   (return (compiler-call #'compile-implicit-progn
		     :form then-forms
		     :forward all)))
      finally (error "No matching result-mode-case for result-mode ~S." result-mode)))


(define-special-operator muerte::inline-values (&all all &result-mode result-mode &form form)
  (let ((sub-forms (cdr form)))
    (if (eq :ignore result-mode)
	(compiler-call #'compile-implicit-progn ; compile only for side-effects.
	  :forward all
	  :form sub-forms)
      (case (length sub-forms)
	(0 (compiler-values ()
	     :functional-p t
	     :returns :multiple-values
	     :type '(values)
	     :code `((:movl :edi :eax)
		     (:xorl :ecx :ecx)
		     (:stc))))
	(1 (compiler-values-bind (&all sub-form &code code &returns returns &type type)
	       (compiler-call #'compile-form-unprotected
		 :result-mode (if (member result-mode +multiple-value-result-modes+)
				  :eax
				result-mode)
		 :forward all
		 :form (first sub-forms))
	     (compiler-values (sub-form)
	       :type (type-specifier-primary type)
	       :returns (if (eq :multiple-values returns)
			    :eax
			  returns))))
	(2 (multiple-value-bind (code functional-p modifies first-values second-values)
	       (make-compiled-two-forms-into-registers (first sub-forms) :eax
						       (second sub-forms) :ebx
						       (all :funobj)
						       (all :env))
	     (compiler-values ()
	       :code (append code
			     ;; (make-immediate-move 2 :ecx)
			     '((:xorl :ecx :ecx) (:movb 2 :cl))
			     '((:stc)))
	       :returns :multiple-values
	       :type `(values ,(type-specifier-primary (compiler-values-getf first-values :type))
			      ,(type-specifier-primary (compiler-values-getf second-values :type)))
	       :functional-p functional-p
	       :modifies modifies)))
	(t (multiple-value-bind (arguments-code stack-displacement arguments-modifies
				 arguments-types arguments-functional-p)
	       (make-compiled-argument-forms sub-forms (all :funobj) (all :env))
	     (multiple-value-bind (stack-restore-code new-returns)
		 (make-compiled-stack-restore stack-displacement result-mode :multiple-values)
	       (compiler-values ()
		 :returns new-returns
		 :type `(values ,@arguments-types)
		 :functional-p arguments-functional-p
		 :modifies arguments-modifies
		 :code (append arguments-code
			       (loop for i from (- (length sub-forms) 3) downto 0
				   collecting
				     `(:locally (:popl (:edi (:edi-offset values ,(* i 4))))))
			       (make-immediate-move (- (length sub-forms) 2) :ecx)
			       `((:locally (:movl :ecx (:edi (:edi-offset num-values))))
				 (:addl 2 :ecx)
				 (:stc))
			       #+ignore
			       (make-compiled-funcall-by-symbol 'muerte.cl::values
								(length sub-forms)
								(all :funobj))
			       #+ignore
			       stack-restore-code)))))))))

(define-special-operator muerte::compiler-typecase (&all all &form form)
  (destructuring-bind (keyform &rest clauses)
      (cdr form)
    (compiler-values-bind (&type keyform-type)
	;; This compiler-call is only for the &type..
	(compiler-call #'compile-form-unprotected
	  :form keyform
	  :result-mode :eax
	  :forward all)
;;;      (warn "keyform type: ~S" keyform-type)
;;;      (warn "clause-types: ~S" (mapcar #'car clauses))
      (declare (ignore keyform-type))
      (let ((clause (find 'muerte.cl::t clauses :key #'car)))
	(assert clause)
	(compiler-call #'compile-implicit-progn
	  :form (cdr clause)
	  :forward all))
      #+ignore
      (loop for (clause-type . clause-forms) in clauses
	  when (movitz-subtypep (type-specifier-primary keyform-type) clause-type)
	  return (compiler-call #'compile-implicit-progn
		   :form clause-forms
		   :forward all)
	  finally (error "No compiler-typecase clause matched compile-time type ~S." keyform-type)))))

(define-special-operator muerte::exact-throw (&all all-throw &form form)
  (destructuring-bind (tag context value-form)
      (cdr form)
    (with-labels (throw (save-tag-variable save-context-var tag-not-found-label))
      (compiler-values ()
	:returns :non-local-exit
	:code (append (compiler-call #'compile-form
			:forward all-throw
			:result-mode :multiple-values
			:form `(muerte.cl:let ((,save-tag-variable ,tag)
					     (,save-context-var ,context))
				 (muerte.cl:multiple-value-prog1
				     ,value-form
				   (muerte::with-inline-assembly (:returns :nothing)
				     (:compile-form (:result-mode :eax) ,save-tag-variable)
				     (:compile-form (:result-mode :ebx) ,save-context-var)
				     (:globally (:call (:edi (:edi-offset dynamic-locate-catch-tag))))
				     (:jnc '(:sub-program (,tag-not-found-label) (:int 108)))
				     (:movl :eax :ebp))))) ; save dynamic-slot in EBP
		      ;; now outside of m-v-prog1's cloak, with final dynamic-slot in ESP..
		      ;; ..unwind it and transfer control.
		      `((:movl :ebp :esp)
			(:popl :ebp)
			(:movl (:ebp -4) :esi)
			(:leal (:esp 8) :esp) ; skip tag and eip
			(:locally (:popl (:edi (:edi-offset dynamic-env)))) ; unwind dynamic env
			(:jmp (:esp -8))))))))

(define-special-operator muerte::with-basic-restart (&all defaults &form form &env env)
  (destructuring-bind ((name function interactive test format-control
			     &rest format-arguments)
		       &body body)
      (cdr form)
    (check-type name symbol "a restart name")
    (let* ((entry-size (+ 10 (* 2 (length format-arguments)))))
      (with-labels (basic-restart-catch (exit-point-offset exit-point))
	(compiler-values ()
	  :returns :multiple-values
	  :code	(append `((:locally (:pushl (:edi (:edi-offset dynamic-env))))
			  (:call (:pc+ 0))
			  ,exit-point-offset
			  (:addl '(:funcall - ',exit-point ',exit-point-offset) (:esp))
			  (:globally (:pushl (:edi (:edi-offset restart-tag))))
			  (:pushl :ebp)
			  (:load-constant ,name :push))
			(compiler-call #'compile-form
			  :defaults defaults
			  :form function
			  :with-stack-used 5
			  :result-mode :push)
			(compiler-call #'compile-form
			  :defaults defaults
			  :form interactive
			  :with-stack-used 6
			  :result-mode :push)
			(compiler-call #'compile-form
			  :defaults defaults
			  :form test
			  :with-stack-used 7
			  :result-mode :push)
			`((:load-constant ,format-control :push)
			  (:pushl :edi))
			(loop for format-argument-cons on format-arguments
			    as stack-use upfrom 11 by 2
			    append
			      (if (cdr format-argument-cons)
				  '((:leal (:esp -15) :eax)
				    (:pushl :eax))
				'((:pushl :edi)))
			    append
			      (compiler-call #'compile-form
				:defaults defaults
				:form (car format-argument-cons)
				:result-mode :push
				:with-stack-used stack-use
				:env env))
			`((:leal (:esp ,(* 4 (+ 6 (* 2 (length format-arguments))))) :eax)
			  (:locally (:movl :eax (:edi (:edi-offset dynamic-env)))))
			(when format-arguments
			  `((:leal (:eax -31) :ebx)
			    (:movl :ebx (:eax -24))))
			(compiler-call #'compile-implicit-progn
			  :forward defaults
			  :env (make-instance 'simple-dynamic-env
				 :uplink env
				 :funobj (defaults :funobj)
				 :num-specials 1)
			  :result-mode :multiple-values
			  :with-stack-used entry-size
			  :form body)
			`((:leal (:esp ,(+ -4 (* 4 entry-size))) :esp)
			  (:locally (:popl (:edi (:edi-offset dynamic-env))))
			  ,exit-point)))))))