;;
;; ruby-runtime
;;

(define (%ruby:core:Fixnum '#())
(define (%ruby:core:Float '#())
(define (%ruby:core:Array '#())

(define (%ruby:meta:class obj)
  (cond
    ((fixnum? obj) %ruby:core::Fixnum)
    ((float? obj) %ruby:core::Float)
    ((vector? obj) %ruby:core::Array)
    (else %ruby:core:Object)))

(define (%ruby:meta:ancestors obj)
  (cond
  ))

(define (%ruby:meta:class obj)
  )
