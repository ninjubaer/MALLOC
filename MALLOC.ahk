Class MALLOC {
	/*
	flags:
	- 0x0000: GMEM_FIXED
	- 0x0002: GMEM_MOVEABLE
	- 0x0040: GMEM_ZEROINIT
	*/
	static Call(size, flags:=0) { ; GMEM_FIXED
		out := DllCall("GlobalAlloc", "uint", flags, "uint", size)
		if !out
			throw MemoryError("GlobalAlloc failed")
		_MALLOC := {base: MALLOC.Prototype, private: {_ptr: 0, _size: size, _flags: flags, _handle: 0, _lock: 0}}
		if flags & 2
			_MALLOC.private._handle := out
		else
			_MALLOC.private._ptr := out
		return _Malloc
	}
	lock() {
		if this.private._lock || this.private._ptr
			return this
		this.private._lock := !!(this.private._ptr := DllCall("GlobalLock", "uint", this.private._handle))
		return this
	}
	unlock() {
		if !this.private._lock
			return this
		if !this.private._ptr
			return (this.private._lock := 0, this)
		return (DllCall("GlobalUnlock", "uint", this.private._ptr), this.private._lock := this.private._ptr := 0, this)
	}
	ptr {
		get {
			if !this.private._ptr
				throw MemoryError("Memory not locked")
			return this.private._ptr
		}
	}
	handle {
		get {
			if !this.private._handle
				throw MemoryError("Memory not moveable")
			return this.private._handle
		}
	}
	size {
		get => this.private._size
		set {
			this.ReAlloc(Value)
		}
	}
	Free() {
		if this.private._ptr && this.private._lock
			return (DllCall("GlobalUnlock", "uint", this.private._ptr), DllCall("GlobalFree", "uint", this.private._handle), this.private._ptr:=this.private._handle:=this.private._size:=this.private._lock:=0, this)
		return (DllCall("GlobalFree", "uint", this.private._ptr), this.private._ptr:=this.private._handle:=this.private._size:=this.private._lock:=0, this)
	}
	ReAlloc(size, flags?) {
		if this.private._handle && !this.private._lock
			return (this.private._handle:=DllCall("GlobalReAlloc", "uint", this.private._handle, "uint", this.private._size:=size, "uint", this.private._flags:=(flags ?? this.private._flags)), this)
		if size > this.private._size
			throw MemoryError("Cannot increase size of " (this.private._lock ? "locked" : "fixed") " memory")
		return (this.private._%((flags??this.private._flags) & 2 ? "handle" : "ptr")% := DllCall("GlobalReAlloc", "uint", this.private._ptr, "uint", this.private._size := size, "uint", this.private._flags:=(flags ?? this.private._flags)), this)

	}
	__Delete() {
		if this.private._ptr && this.private._lock
			return (DllCall("GlobalUnlock", "uint", this.private._ptr), DllCall("GlobalFree", "uint", this.private._handle), this)
		return (DllCall("GlobalFree", "uint", this.private._ptr), this)
	}
	NumPut(offset, args*) {
		static types := {int: 4, uint: 4, short: 2, ushort: 2, char: 1, uchar: 1, float: 4, double: 8, int64: 8, uint64: 8}
		if args.Length & 1 || args.Length < 2
			throw Error("NumPut: Invalid number of arguments")
		if !this.private._ptr
			throw MemoryError("Memory not locked")
		Loop args.Length // 2
			NumPut(args[A_Index*2-1], args[A_Index*2], this.private._ptr, offset), offset += types.%args[A_Index*2-1]%
		return this
	}
}
