Class {
	#name : #SOMMethodParser,
	#superclass : #SOMParser,
	#instVars : [
		'mgenc'
	],
	#category : #'AweSOM-Compiler'
}

{ #category : #'accept and expect' }
SOMMethodParser >> acceptOneOf: symbols [
	(self symIn: symbols) ifTrue: [
		self getSym.
		^ true ].

	^ false
]

{ #category : #patterns }
SOMMethodParser >> argument [
	^ self variable
]

{ #category : #patterns }
SOMMethodParser >> assignation [
	| list |
	list := OrderedCollection new.
	
	self assignments: list.

	self evaluation.
	
	list do: [:v | mgenc bcDup ].
	list do: [:v | mgenc lookUpAndPop: v in: universe ]
]

{ #category : #patterns }
SOMMethodParser >> assignment [
	| v |
	v := self variable.
	mgenc addLiteralIfAbsent: v.
	
	self expect: #assign.
	
	^ v
]

{ #category : #patterns }
SOMMethodParser >> assignments: vars [
	self symIsIdentifier ifTrue: [
		| var |
		var := self assignment.
		
		self peek.
		
		nextSym == #assign ifTrue: [
			self assignments: vars.
		].
	
		vars add: var.
	]
]

{ #category : #patterns }
SOMMethodParser >> binaryMessage: superSend [
	| sel |
	sel := self binarySelector.
	
	mgenc addLiteralIfAbsent: sel.
	
	self binaryOperand: false.
	
	superSend ifTrue: [mgenc bcSuperSend: sel]
				ifFalse:[mgenc bcSend: sel].
]

{ #category : #patterns }
SOMMethodParser >> binaryOperand: superSend [
	| doSuper |
	doSuper := self primary: superSend.
	
	[self symIsIdentifier] whileTrue:
		[self unaryMessage: doSuper].
	
	^ doSuper
]

{ #category : #patterns }
SOMMethodParser >> binaryPattern [
	mgenc signature: self binarySelector.
	mgenc addArgumentIfAbsent: self argument.
]

{ #category : #'selector patterns' }
SOMMethodParser >> binarySelector [
	| s |
	s := text asSymbol.
	
	(self accept: #or)		ifFalse: [
	(self accept: #comma)	ifFalse: [
	(self accept: #minus)	ifFalse: [
	(self accept: #equal)	ifFalse: [
	(self acceptOneOf: SingleOpSyms) ifFalse: [
	(self accept: #operatorSequence) ifFalse: [
	 self expect: #none    ]]]]]].

	^ s
]

{ #category : #patterns }
SOMMethodParser >> blockArgPattern [
	| blockSig |
	sym == #colon ifTrue: [self blockPattern ].
]

{ #category : #patterns }
SOMMethodParser >> blockArguments [
	[ self expect: #colon.
	  mgenc addArgumentIfAbsent: self argument
	] doWhileTrue: [sym == #colon].
]

{ #category : #patterns }
SOMMethodParser >> blockBody: hasSeenPeriod [
	(self accept: #exit) ifTrue: [
		^ self result.
	].

	sym == #endBlock ifTrue: [
		hasSeenPeriod ifTrue: [ mgenc removeLastBytecode ].
		^ mgenc
			bcReturnLocal;
			finished.
	].

	sym == #endTerm ifTrue: [
		^ mgenc returnSelf; finished.
	].

	self expression.
	(self accept: #period) ifTrue: [
		mgenc bcPop.
		self blockBody: true.
	].

]

{ #category : #patterns }
SOMMethodParser >> blockContents [
	(self accept: #or) ifTrue: [
		self locals.
		self expect: #or.
	].

	self blockBody: false.
]

{ #category : #patterns }
SOMMethodParser >> blockPattern [
	self blockArguments.
	self expect: #or.
]

{ #category : #patterns }
SOMMethodParser >> evaluation [
	| superSend |
	superSend := self primary: false.
	
	(self symIsIdentifier     or: [
	 sym == #keyword          or: [
	 sym == #operatorSequence or: [
	 self symIn: BinaryOpSyms]]]) ifTrue: [
		self messages: superSend.
	]
]

{ #category : #'accept and expect' }
SOMMethodParser >> expectOneOf: syms [
	| msg |
	(self acceptOneOf: syms)
		ifTrue: [	^ true. ].
	
	msg := RWBinaryOrTextStream on: String new.
	msg nextPutAll: 'unexpected symbol in line '.
	msg nextPutAll: lexer currentLineNumber asString.
	msg nextPutAll: '. Expected one of '.
	
	syms do: [:s | 
		msg nextPutAll: s.
		msg nextPutAll: ', '].
	
	msg nextPutAll: 'but found '.
	msg nextPutAll: sym asString.
	
	self printableSymbol ifTrue: [
		msg nextPutAll: ' (', text contents, ')'].
	
	msg nextPutAll: ': '.
	msg nextPutAll: lexer rawBuffer.
	
	Error signal: msg.
]

{ #category : #patterns }
SOMMethodParser >> expression [
	self peek.
	nextSym == #assign
		ifTrue:  [self assignation.]
		ifFalse: [self evaluation. ]
]

{ #category : #helper }
SOMMethodParser >> fakeCgenc [

	cgenc := SOMClassGenerationContext new
			theName: #Dummy;
			yourself.
]

{ #category : #helper }
SOMMethodParser >> fakeMgenc [

	mgenc := (universe methodGenClass named: #dummy)
		somHolder: cgenc;
		yourself
]

{ #category : #patterns }
SOMMethodParser >> formula [
	| superSend |
	superSend := self binaryOperand: false.
	
	(sym == #operatorSequence or: [self symIn: BinaryOpSyms])
		ifTrue: [self binaryMessage: superSend ].
	
	"only the first message in a sequence can be a super send"
	[sym == #operatorSequence or: [self symIn: BinaryOpSyms]]
		whileTrue: [self binaryMessage: false ].
]

{ #category : #patterns }
SOMMethodParser >> keyword [
	| s |
	s := text.
	self expect: #keyword.
	^ s
]

{ #category : #patterns }
SOMMethodParser >> keywordMessage: superSend [
	| kw sel |
	kw := RWBinaryOrTextStream on: String new.
	
	[ kw nextPutAll: self keyword.
	  self formula.
	] doWhileTrue: [sym == #keyword].

	sel := kw contents asSymbol.
	
	mgenc addLiteralIfAbsent: sel.
	superSend ifTrue:  [mgenc bcSuperSend: sel]
				ifFalse: [mgenc bcSend: sel]
]

{ #category : #'selector patterns' }
SOMMethodParser >> keywordPattern [
	| kw |
	kw := RWBinaryOrTextStream on: String new.
	[ kw nextPutAll: self keyword.
	  mgenc addArgumentIfAbsent: self argument
	] doWhileTrue: [sym == #keyword].

	mgenc signature: kw contents asSymbol. "(universe newSymbol:)"
]

{ #category : #'selector patterns' }
SOMMethodParser >> keywordSelector [
	| s |
	s := text asSymbol.
	
	self expectOneOf: KeywordSelectorSyms.
	
	^ s
]

{ #category : #patterns }
SOMMethodParser >> literal [
	sym == #pound    ifTrue: [ ^ self literalSymbol. ].
	sym == #STString ifTrue: [ ^ self literalString. ].

	self literalNumber.
]

{ #category : #patterns }
SOMMethodParser >> literalDecimal [
	^ self literalInteger.
]

{ #category : #patterns }
SOMMethodParser >> literalInteger [
	| val |
	val := text contents asInteger.
	self expect: #integer.
	^ val
]

{ #category : #patterns }
SOMMethodParser >> literalNumber [
	| val lit |
	val := sym == #minus	ifTrue: [self negativeDecimal]
								ifFalse:[self literalDecimal ].
	lit := universe newNumber: val.
	mgenc addLiteralIfAbsent: lit.
	mgenc bcPushConstant: lit.
]

{ #category : #patterns }
SOMMethodParser >> literalString [
	| s |
	s := universe newString: self string.
	mgenc addLiteralIfAbsent: s.
	mgenc bcPushConstant: s.
]

{ #category : #patterns }
SOMMethodParser >> literalSymbol [
	| symbol |
	self expect: #pound.
	symbol := sym == #STString	 ifTrue:  [universe newSymbol: self string]
									 ifFalse: [universe newSymbol: self selector].
	
	mgenc addLiteralIfAbsent: symbol.
	mgenc bcPushConstant: symbol.
]

{ #category : #patterns }
SOMMethodParser >> locals [
	[self symIsIdentifier] whileTrue: [
		mgenc addLocalIfAbsent: self variable.
	]
]

{ #category : #patterns }
SOMMethodParser >> messages: superSend [
	| doSuper |
	doSuper := superSend.
		
	self symIsIdentifier ifTrue: [
		[ self unaryMessage: doSuper.
		  doSuper := false.
		] doWhileTrue: [self symIsIdentifier].
		
		[sym == #operatorSequence or: [self symIn: BinaryOpSyms]] whileTrue: [
			self binaryMessage: false.
		].
	
		sym == #keyword ifTrue: [
			self keywordMessage: false.
		].
		^ doSuper.
	].

	(sym == #operatorSequence or: [self symIn: BinaryOpSyms]) ifTrue: [
		[ self binaryMessage: doSuper.
		  doSuper := false.
		] doWhileTrue: [sym == #operatorSequence or: [self symIn: BinaryOpSyms]].
		
		sym == #keyword ifTrue: [
			self keywordMessage: false.
		].
		^ doSuper.
	].

	self keywordMessage: doSuper.

]

{ #category : #patterns }
SOMMethodParser >> method [
	self methodName.
	self expect: #equal.
	
	self methodBody.
		
	^ mgenc
]

{ #category : #patterns }
SOMMethodParser >> methodBlock [
	self expect: #newTerm.
	self blockContents.
	
	mgenc isFinished ifFalse: [
		mgenc
			bcPop;
			returnSelf;
			finished.
	].

	self expect: #endTerm.
]

{ #category : #patterns }
SOMMethodParser >> methodBody [
	sym == #primitive
		ifTrue:  [ mgenc isPrimitive: true.
					 self primitiveBlock.]
		ifFalse: [ self methodBlock ].

]

{ #category : #patterns }
SOMMethodParser >> methodName [
	mgenc := universe methodGenClass new.
	mgenc addArgumentIfAbsent: #self.
	mgenc holder: cgenc.
	
	self symIsIdentifier ifTrue: [ ^ self unaryPattern   ].
	sym == #keyword      ifTrue: [ ^ self keywordPattern ].
	
	"else"
	^ self binaryPattern.
]

{ #category : #helper }
SOMMethodParser >> methodParser [
	^ super methodParser
		mgenc: (universe methodGenClass blockIn: mgenc);
		yourself
]

{ #category : #accessing }
SOMMethodParser >> mgenc [
	^ mgenc
]

{ #category : #accessing }
SOMMethodParser >> mgenc: anMgenc [
	mgenc := anMgenc
]

{ #category : #patterns }
SOMMethodParser >> negativeDecimal [
	self expect: #minus.
	^ self literalInteger negated 
]

{ #category : #patterns }
SOMMethodParser >> nestedBlock [
	self expect: #newBlock.
	
	mgenc isBlockMethod: true.
	
	self blockArgPattern.
	self blockContents.
	
	mgenc isFinished ifFalse: [
		mgenc bcReturnLocal; finished.
	].

	self expect: #endBlock.
	
	^ mgenc
]

{ #category : #patterns }
SOMMethodParser >> nestedTerm [
	self expect: #newTerm.
	
	self expression.
	
	self expect: #endTerm.
]

{ #category : #patterns }
SOMMethodParser >> parseNestedBlock [
	| parser result blockMethod |
	
	parser := self methodParser.
	parser parseState: self parseState.
	
	result := parser apply: #nestedBlock.
	
	blockMethod := result assembleIn: universe.
	mgenc bcPushBlock: blockMethod.
	
	self parseState: parser parseState.
	
	^ result
]

{ #category : #patterns }
SOMMethodParser >> primary: doSuper [
	| superSend |
	superSend := doSuper.
	
	self symIsIdentifier ifTrue: [
		| v |
		v := self variable.
		v = #super ifTrue: [
			"v := #self. sends to #super push #self as receiver"
			superSend := true.
		].
		"self genPushVariable: v."
		mgenc lookupVariable: v in: universe.
		^ superSend.
	].

	sym == #newTerm ifTrue: [
		self nestedTerm.
		^ superSend.
	].

	sym == #newBlock ifTrue: [
		self parseNestedBlock.
		^ superSend
	].

	self literal.
	^ superSend
]

{ #category : #patterns }
SOMMethodParser >> primitiveBlock [
	self expect: #primitive.
	mgenc fakeSource: '^ SOMPrimitives ', 
						 self cgenc theName,
						 mgenc combineSelectorAndArgs.
]

{ #category : #patterns }
SOMMethodParser >> result [
	self expression.
	
	mgenc isBlockMethod
		ifTrue:  [ mgenc bcReturnNonLocal ]
		ifFalse: [ mgenc bcReturnLocal    ].
	
	mgenc finished.
	
	self accept: #period.
]

{ #category : #patterns }
SOMMethodParser >> selector [
	(sym == #operatorSequence or: [self symIn: SingleOpSyms])
		ifTrue: [^ self binarySelector ].
	
	(sym == #keyword or: [sym == #keywordSequence])
		ifTrue: [^ self keywordSelector].
	
	^ self unarySelector
]

{ #category : #patterns }
SOMMethodParser >> string [
	| s |
	s := text contents.
	self expect: #STString.
	^ s
]

{ #category : #patterns }
SOMMethodParser >> unaryMessage: superSend [
	| sel |
	sel := self unarySelector.
	
	mgenc emitSend: sel isSuper: superSend 
]

{ #category : #patterns }
SOMMethodParser >> unaryPattern [
	mgenc signature: self unarySelector
]

{ #category : #'selector patterns' }
SOMMethodParser >> unarySelector [
	^ self identifier asSymbol
]
