#lang racket

(require (for-syntax racket/syntax))

(provide define-bit-struct *->bytes bytes->* build-*)

; Extract bits from a bit field
(define (extract-bytes buffer from [to #f])
  ; Extract the bytes we're interested in
  (define f (quotient from 8))
  (define t (if to 
                (let ([q (quotient to 8)])
                  (if (zero? (remainder to 8)) q (+ 1 q)))
                (bytes-length buffer)))
  (define chunk (subbytes buffer f t))
  ; Convert to a base 256 number
  (define numeric
    (for/fold ([total 0])
              ([byte (in-bytes chunk)])
      (+ byte (* total 256))))
  ; Shift off the ends
  (bitwise-and
   (arithmetic-shift numeric 
                     (if to 
                         (let ([r (remainder to 8)])
                           (if (zero? r) r (- r 8)))
                         0))
   (- (arithmetic-shift 1 (- to from)) 1)))

; Turn a number into a byte field
(define (number->bytes n length)
  (define b
    (list->bytes 
     (let loop ([n n] [acc '()])
       (cond
         [(= n 0) acc]
         [else
          (loop (quotient n 256) (cons (remainder n 256) acc))]))))
  (bytes-append
   (make-bytes (- length (bytes-length b)) 0)
   b))

; Bind a struct (and normal functions) plus these new functions:
; build-* takes keyword arguments for parameters (default = 0)
; *->bytes turns a struct into bytes
; bytes->* takes bytes and returns a struct
(define-syntax (define-bit-struct stx)
  (syntax-case stx ()
    [(_ struct-name ([name* bits*] ...))
     ; Get some identifiers we'll need
     (with-syntax ([maker-name (format-id stx "make-~a" #'struct-name)]
                   [builder-name (format-id stx "build-~a" #'struct-name)]
                   [bytes->-name (format-id stx "bytes->~a" #'struct-name)]
                   [->bytes-name (format-id stx "~a->bytes" #'struct-name)])
       #'(begin
           ; Bind the structure
           (define-struct struct-name (name* ...) #:transparent)
           
           ; Create the builder function
           (define builder-name
             (make-keyword-procedure
              (λ (keys vals)
                ; Create an association map from the new values
                (define new-values
                  (for/list ([k (in-list (map string->symbol 
                                              (map keyword->string keys)))]
                             [v (in-list vals)])
                    (list k v)))

                ; Build a new structure
                (apply 
                 maker-name
                 (for/list ([name (in-list '(name* ...))]
                            [bits (in-list '(bits* ...))])
                   (cond
                     [(assoc name new-values)
                      => (λ (kv) (second kv))]
                     [(eq? bits '_) #""]
                     [else            0]))))))
           
           ; Create the parser function
           (define (bytes->-name buffer)
             ; Set names with parameters (easier than making lots of ids)
             (define name* (make-parameter 0)) ...
             ; Unpack fields into those parameters as integers
             ; _ is different, it stores any remaining bytes
             (define _
               (for/fold ([offset 0])
                 ([name (in-list (list name* ...))]
                  [bits (in-list '(bits* ...))])
                 (cond
                   [(number? bits)
                    (name (extract-bytes buffer offset (+ offset bits)))
                    (+ offset bits)]
                   [else
                    (name (subbytes buffer (quotient offset 8)))
                    offset])))
             ; Create the structure
             (apply 
              maker-name
              (for/list ([name (list name* ...)])
                (name))))
           
           ; Create the ->bytes function
           (define (->bytes-name data-struct)
             (define data (struct->vector data-struct))
             (let loop ([bits '(bits* ...)]
                        [buffer 0]
                        [buffer-bits 0]
                        [index 1])
               (cond
                 ; Full buffer, transfer it
                 [(and (> buffer-bits 0) (zero? (remainder buffer-bits 8)))
                  (bytes-append
                   (number->bytes buffer (quotient buffer-bits 8))
                   (loop bits 0 0 index))]
                 ; Nothing left
                 [(null? bits)
                  #""]
                 ; Current value is bytes, copy directly
                 [(eq? (first bits) '_)
                  (bytes-append
                   (vector-ref data index)
                   (loop (rest bits) buffer buffer-bits (+ index 1)))]
                 ; Otherwise, add to buffer
                 [else
                  (loop
                   (rest bits)
                   (+ (* buffer (arithmetic-shift 1 (first bits)))
                      (vector-ref data index))
                   (+ buffer-bits (first bits))
                   (+ index 1))])))))]))
