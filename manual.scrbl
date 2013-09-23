#lang scribble/manual

@(require scribble/eval
          (for-label racket bit-struct
                     images/flomap
                     racket/flonum))

@title{bit-struct: Binary structs with conversion to/from bytes}
@author{@author+email["John-Paul Verkamp" "me@jverkamp.com"]}

This package extends standard Racket structs to make them more useful for
bitfield type data, such as that used in packets over a network. It creates
the normal accessors for structure along with defining three new methods:

@defmodule[bit-struct]

@itemlist[
  @item{@code{build-*} creates a structure via keyword parameters (defaulting to 0)}
  @item{@code{*->bytes} converts a @code{bit-struct} into @code{bytes}}
  @item{@code{bytes->*} converts @code{bytes} into a @code{bit-struct} of the given type}
]

@bold{Development} Development of this library is hosted by @hyperlink["http://github.com"]{GitHub} at the following project page:

@url{https://github.com/jpverkamp/bit-struct/}

@section{Installation}

@commandline{raco pkg install git://github.com/jpverkamp/bit-struct}

@section{Functions}

@defproc[(define-bit-struct 
           [id symbol?] 
           [kv (List symbol? (or/c exact-nonnegative-integer? '_))] ...)
         void]{
  Define a new bit structure. Creates all of the normal @code{struct} methods
  along with the three new methods described below (where @code{*} is the 
  @code{id} specified above).
                            
  For each field, specific either the number of bits that it takes up or
  @code{_} (as the last item only) to return any unconverted @code{bytes}
  directly.
}

@defproc[(build-* [#:key value any] ...) struct?]{
  Creates a new structure using keyword based arguments derived from the
  structure fields. Any keywords not specified will default to 0.
}
               
@defproc[(*->bytes [data struct?]) bytes?]{
  Convert a @code{bit-struct} into @code{bytes} using the defined bit widths.
}

@defproc[(bytes->* [buffer bytes?]) struct?]{
  Convert @code{bytes} into a @code{bit-struct} using the defined bit widths.
}

@section{Examples}

@interaction[
(require "bit-struct/main.rkt")

(define-bit-struct dns
  ([id      16]
   [qr      1]  [opcode  4]  [aa      1]  [tc      1]  [rd      1] 
   [ra      1]  [z       3]  [rcode   4]
   [qdcount 16]
   [ancount 16]
   [nscount 16]
   [arcount 16]
   [data    _]))

(define packet
  (build-dns
   #:id (random 65536)
   #:tc 1
   #:qdcount 1
   #:data
   (bytes-append ; query / question
    #"\3www\6google\3com\0" ; query (www.google.com)
    (bytes 0 1) ; query type (1 = Type A, host address)
    (bytes 0 1) ; query class (1 = IN, Internet address)
    )))

packet
       
(dns->bytes packet)

(bytes->dns (dns->bytes packet))
]

@section{License}

This program is free software: you can redistribute it and/or modify it
under the terms of the 
@hyperlink["http://www.gnu.org/licenses/lgpl.html"]{GNU Lesser General
Public License} as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License and GNU Lesser General Public License for more
details.
