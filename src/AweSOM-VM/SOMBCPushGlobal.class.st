Class {
	#name : #SOMBCPushGlobal,
	#superclass : #SOMBytecodeWithIndex,
	#category : #'AweSOM-Interpreter'
}

{ #category : #accessing }
SOMBCPushGlobal >> global [
	^ self literalValue
]

{ #category : #accessing }
SOMBCPushGlobal >> stackDepth [

	^ 1
]
