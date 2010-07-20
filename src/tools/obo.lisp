(in-package :cl-user)

(defclass obo ()
  ((path :initarg :path :initform nil :accessor path)
   (header :initarg :header :initform nil :accessor header)
   (terms :initarg :terms :initform nil :accessor terms)
   ))

(defmethod read-obo ((g obo))
  (with-open-file (f (path g))
    (setf (header g) (read-obo-key-values g f))
    (setf (terms g)
	  (loop for line = (read-line f  nil :eof)
	     until (eq line :eof)
	     for part = (caar (all-matches line "^\\[(.*?)\\]\s*" 1))
	     do  (assert (or part (equal line ""))  () "Didn't find a record! '~a'" line)
	     when part collect  (read-obo-record g part f)
	     ))
    (values)))

(defmethod tags ((g obo))
  (loop for term in (terms g)
     with tags
     do
     (loop for (tag nil) on (cdr term) by #'cddr
	do (pushnew tag tags))
     finally (return tags)))

(defmethod read-obo-key-values ((g obo) stream)
  (loop for line = (read-line stream)
     for (tag value) = (car (all-matches line "^(\\S+): (.*?)\\s*(![^\"]+?){0,1}$" 1 2))
     until (null tag)
     do (when (equal tag "relationship")
	  (destructuring-bind (realtag realvalue) (car (all-matches value "^(\\S+) (.*?)(![^\"]+?){0,1}$" 1 2))
	    (setq tag realtag)
	    (setq value realvalue)))
       (setq value (regex-replace-all "\\\\(.)" value "$1"))
       (when (equal tag "def")
	 (setq value (regex-replace-all "\\s*\"\"" value "")))
       (when (equal tag "xref_analog")
	 (setq value (regex-replace-all "\\s*" value ""))) 
       (when (or (equal tag "synonym") (equal tag "def"))
	 (destructuring-bind (synonym sources type) (car (all-matches value "\"(.*?)\"\\s+((EXACT|RELATED|BROAD|NARROW)\\s+){0,1}\\[(.*)\\]" 1 4 3))
	   (setq value (list* synonym type (remove "" (split-at-regex sources ",\\s*") :test 'equal)))))
     append (list (intern (string-upcase tag) 'keyword) value)
     ))

(defmethod read-obo-record ((g obo) type stream)
  (let ((it (cons type (read-obo-key-values g stream))))
;    (print-db it)
    it))
