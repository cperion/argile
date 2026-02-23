# Terra: The Complete Reference

> *Terra is a low-level systems programming language designed to be meta-programmed
> by LuaJIT. This document covers everything from first principles to production
> patterns. It is intended to be the only Terra reference you need.*

## Table of Contents

1. [Philosophy and Design](#1-philosophy-and-design)
2. [Architecture: The Two-Phase Model](#2-architecture-the-two-phase-model)
3. [Installation and Toolchain](#3-installation-and-toolchain)
4. [The Terra/Lua Boundary](#4-the-terralua-boundary)
5. [Types](#5-types)
   - 5.1 Primitive Types
   - 5.2 The Type Hierarchy as Lua Values
   - 5.3 Pointer Types
   - 5.4 Array Types
   - 5.5 Vector Types
   - 5.6 Function Types
   - 5.7 Tuple Types
   - 5.8 Struct Types
   - 5.9 Type Introspection
6. [Variables and Scoping](#6-variables-and-scoping)
7. [Expressions and Operators](#7-expressions-and-operators)
   - 7.0 Literals
   - 7.1 Arithmetic and Logical Operators
   - 7.2 Comparison Operators
   - 7.3 The @ Dereference and & Address-Of
   - 7.4 Casts
   - 7.5 Sizeof
8. [Control Flow](#8-control-flow)
   - 8.1 if / elseif / else / end
   - 8.2 Loops: while and repeat/until
   - 8.3 Loops: for (numeric)
   - 8.4 Loops: for (iterator)
   - 8.5 switch Statements
   - 8.6 goto and Labels
   - 8.7 defer
   - 8.8 return
9. [Functions](#9-functions)
10. [Structs](#10-structs)
11. [Pointers and Memory](#11-pointers-and-memory)
12. [Arrays and Vectors](#12-arrays-and-vectors)
13. [Quotes and Escapes: The Metaprogramming Primitives](#13-quotes-and-escapes-the-metaprogramming-primitives)
14. [Macros](#14-macros)
15. [Exotypes: Operator Overloading and Metamethods](#15-exotypes-operator-overloading-and-metamethods)
16. [Environments and Symbol Resolution](#16-environments-and-symbol-resolution)
17. [The terralib API](#17-the-terralib-api)
   - 17.1 Core Compilation Functions
   - 17.2 Type Constructors
   - 17.3 Function Manipulation
   - 17.4 Saving Compiled Code
   - 17.5 Linking
   - 17.6 Symbol and Quote Utilities
   - 17.7 Memory and Value Utilities
   - 17.8 Intrinsics
   - 17.9 Atomic Operations and Memory Ordering
   - 17.10 Targets
18. [C Interop](#18-c-interop)
19. [Compilation Model and Targets](#19-compilation-model-and-targets)
20. [SIMD and Vector Programming](#20-simd-and-vector-programming)
21. [Atomic Operations and Memory Ordering](#21-atomic-operations-and-memory-ordering)
22. [Language Extensions: The Lexer/Parser Hook System](#22-language-extensions-the-lexerparser-hook-system)
    - 22.1 How the Extension System Works
    - 22.2 The Lexer API
    - 22.3 Token Structure
    - 22.4 Writing an Expression Extension
    - 22.5 Writing a Statement Extension
    - 22.6 Registering Extensions
    - 22.7 Recursive Extensions
    - 22.8 Extension Error Handling
23. [Building DSLs](#23-building-dsls)
24. [High-Performance Patterns via Metaprogramming](#24-high-performance-patterns-via-metaprogramming)
25. [Error Handling Patterns](#25-error-handling-patterns)
26. [Debugging and Introspection](#26-debugging-and-introspection)
27. [Complete API Reference](#27-complete-api-reference)
28. [Known Quirks and Sharp Edges](#28-known-quirks-and-sharp-edges)
29. [Patterns and Idioms](#29-patterns-and-idioms)
30. [The GIS Case Study: Everything Together](#30-the-gis-case-study-everything-together)
31. [Appendix A: Grammar Reference](#appendix-a-grammar-reference)
32. [Appendix B: LLVM Intrinsics Quick Reference](#appendix-b-llvm-intrinsics-quick-reference)
33. [Appendix C: Platform Notes](#appendix-c-platform-notes)
34. [Appendix D: Changelog and Version History](#appendix-d-changelog-and-version-history)

---

## 1. Philosophy and Design

### 1.1 Why Terra Exists

Terra fills the gap between high-level scripting languages (used for productivity and meta-programming) and low-level system languages (used for performance). The specific problems with C metaprogramming (macros) include lack of hygiene, poor type safety, and inability to perform complex logic. C++ templates and similar compile-time evaluation features (like Zig comptime) add significant complexity to the compiler and the language itself, often resulting in poor error messages and slow compilation times.

The key insight of Terra is to separate the meta-language from the object language cleanly, and make the meta-language a real, existing programming language (Lua). This approach avoids retrofitting a high-level language with low-level features or adding a complex meta-language to a low-level language. By embedding Terra (the low-level object language) in Lua (the high-level meta-language), Terra provides the benefits of multi-language programming while minimizing the complexity added to either language.

### 1.2 The Deep Module Insight

By treating the language itself as the ultimate deep module, Terra shifts the paradigm of library design. In traditional low-level languages, a library's interface is a set of exposed functions and structs (typically via header files). In Terra, because Lua is the meta-language, a library can expose a programmatic interface that generates Terra code. The interface becomes the Lua API or DSL (Domain Specific Language) that the user interacts with, and the implementation is the LLVM IR generated by Terra.

This changes library design from "what functions do I expose" to "what should call sites look like." Library authors can build custom notations and abstractions in Lua that compile down to highly optimized Terra code, effectively creating specialized DSLs for their specific problem domains.

### 1.3 Design Decisions and Their Consequences

**Why LuaJIT:** LuaJIT is chosen because it is a fast, tracing JIT compiler for Lua. Lua was originally designed with C interoperability in mind, making it an ideal host language. Its simplicity, lightweight nature, and table-based data structures make it excellent for meta-programming and AST manipulation.

**Why LLVM:** LLVM provides a robust, production-quality backend for generating optimized machine code across multiple architectures. It allows Terra to leverage state-of-the-art compiler optimizations and easily interface with C.

**Why C Compatibility:** C compatibility is crucial for interacting with the vast ecosystem of existing low-level libraries and systems. Terra can seamlessly call C functions, use C structs, and be embedded in C programs, ensuring it can be adopted in real-world scenarios.

**Why not GC in Terra:** Terra uses manual memory management (like C) rather than Garbage Collection (GC) to provide predictable performance and fine-grained control over memory layout. This is essential for high-performance computing, where GC pauses and memory overhead are unacceptable. The explicit tradeoff is that the programmer is responsible for memory safety in Terra, while Lua handles the high-level, GC-managed logic.

### 1.4 What Terra Is Not

Terra is not a replacement for Lua; rather, it is a complement. It is not designed to be a general-purpose high-level scripting language. It is also not a "safer C" (it still allows raw pointers and manual memory management without built-in bounds checking). Instead, Terra plays a very specific role: it is a low-level, high-performance systems language designed specifically to be meta-programmed and orchestrated by a high-level host language (Lua). It fills the niche where you need the performance of C but the generative power of a dynamic scripting language.

---

## 2. Architecture: The Two-Phase Model

### 2.1 Phase 1: Lua Execution

During the first phase of execution, the Lua interpreter runs the top-level script. Terra functions, type definitions, and macro invocations are all evaluated as Lua statements. Because Lua acts as the meta-language, it has full access to the program state before any Terra code is compiled. During this phase, you can programmatically construct Terra types (e.g., using `terralib.types.newstruct()`), generate code using quotes and escapes, and define or specialize Terra functions based on runtime parameters. Essentially, Lua acts as a powerful preprocessor and orchestrator, evaluating type macros and resolving escapes to produce a fully specialized, un-typed abstract syntax tree (AST) for the Terra compiler.

### 2.2 Phase 2: Terra Compilation

In the second phase, Terra takes the specialized AST generated during the Lua phase and compiles it. Because the AST provided by Lua is concrete, monomorphic, and fully resolved, Terra's compilation process is extremely fast. It does not need to perform complex template instantiation or deal with ambiguous generic types like a C++ compiler does. Terra simply type-checks the monomorphic AST and lowers it directly to LLVM Intermediate Representation (IR). LLVM then optimizes this IR and generates high-performance machine code. This clean separation ensures that all high-level logic (like resolving types and generating boilerplate) is handled by Lua, leaving Terra to focus purely on efficient low-level code generation.

### 2.3 JIT vs AOT

By default, Terra functions are Just-In-Time (JIT) compiled on demand. Compilation occurs the first time a function is called, or when it is referenced by another function that is being compiled. You can also force a function to compile immediately by calling the `:compile()` method on the function object. For Ahead-Of-Time (AOT) compilation and production deployment, Terra provides the `terralib.saveobj` API. This allows you to compile Terra functions into native object files (`.o`), static libraries (`.a`), shared libraries (`.so`/`.dylib`), or even standalone executables. This means you can use Lua to meta-program and optimize your code at build time, and then ship a pure native binary that has no dependency on the Lua or Terra runtimes.

### 2.4 The Symbol Table

When the Terra compiler encounters a symbol, it first looks in the local lexical environment of the `terra` function. If the symbol is not found, it continues the search in the enclosing Lua environment, following standard lexical scoping rules. If the symbol resolves to a Lua value (like a number, table, or type), Terra attempts to convert it to an equivalent Terra value at compile time. This allows seamless reference to Lua variables and C functions (imported via `terralib.includec`) directly from Terra code. When writing language extensions or custom DSLs, you can manually control symbol resolution by providing custom environment tables to functions like `terralib.loadstring`, allowing for sandboxed or strictly controlled compilation contexts.

---

## 3. Installation and Toolchain

### 3.1 Building from Source

Terra relies on LLVM and Clang (versions 11 through 21) and LuaJIT. To build from source:

1. Install dependencies: CMake (>= 3.5), GNU Make, and a C++17 compliant compiler. On Linux/macOS, install LLVM and Clang development packages. On Windows, Visual Studio 2022 is required.
2. Clone the repository: `git clone https://github.com/terralang/terra.git`
3. Build using CMake:

    ```bash
    cd terra/build
    cmake -DCMAKE_INSTALL_PREFIX=$PWD/../install ..
    make install -j4
    ```

Common build failures often relate to LLVM path detection. If CMake cannot find LLVM, explicitly provide its path: `-DCMAKE_PREFIX_PATH=/path/to/llvm/install`. On macOS, ensure the SDK path is exported: `export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"`.

**CMake Build Flags:**
* `-DTERRA_ENABLE_CUDA=ON/OFF` - Force CUDA support on/off (auto-detected by default).
* `-DTERRA_STATIC_LINK_LLVM=ON` (default) - Statically link LLVM.
* `-DTERRA_SLIB_INCLUDE_LLVM=ON` (default, except Windows) - Include LLVM in `libterra_s.a`.
* `-DTERRA_STATIC_LINK_LUAJIT=ON` (default) - Statically link LuaJIT.
* `-DTERRA_SLIB_INCLUDE_LUAJIT=ON` (default, except Windows) - Include LuaJIT in `libterra_s.a`.

AMD GPU (HIP) and Intel GPU (SPIR-V) support is also available (experimental, requires LLVM 18+).

### 3.2 The terra Executable

The `terra` executable acts as a drop-in replacement for the standard Lua interpreter, augmented with Terra capabilities. Running `./terra` without arguments launches an interactive Read-Eval-Print-Loop (REPL) where you can type both Lua and Terra code.

Running `./terra myfile.t` executes the top-level code in `myfile.t` as a Lua script (with Terra compilation available). The `.t` extension is conventional for Terra scripts, but they are parsed exactly like `.lua` files. You can use the `-e` flag to execute a specific string of code directly from the command line: `./terra -e 'print("hello")'`.

### 3.3 Using Terra as a Library

Terra can be embedded directly in C/C++ applications by linking against `libterra_s.a` (or `terra.dll` on Windows). The embedding API is similar to Lua's C API. To initialize Terra, you first create a standard Lua state (`luaL_newstate()`) and then pass it to `terra_init(L)`. You can then execute Terra/Lua scripts using `terra_dofile(L, filename)` or `terra_dostring`. Because Terra relies on LLVM and LuaJIT, the standard thread safety constraints of those libraries apply: a single `lua_State` (and its associated Terra state) cannot be accessed concurrently from multiple threads without explicit locking.

### 3.4 Editor Support and LSP

Terra provides syntax highlighting packages for popular editors like Vim, VS Code, and Sublime Text. Because Terra types and functions are constructed dynamically during Lua execution, building a fully accurate static Language Server Protocol (LSP) is challenging. Standard Lua LSPs (like `lua-language-server`) can provide completions for the Lua portions of the codebase, but they will not understand the internal semantics of `terra` blocks or dynamically generated exotypes. For best results, rely on standard Lua tooling for the meta-programming layers and use Terra's reflection APIs (e.g., `:printpretty()`, `:gettype()`) within the REPL for debugging the generated low-level code.

---

## 4. The Terra/Lua Boundary

### 4.1 Calling Terra from Lua

Terra functions are first-class Lua values and can be called directly from Lua. When a Terra function is invoked from Lua, the arguments are automatically converted from Lua types to the expected Terra types using LuaJIT's Foreign Function Interface (FFI) semantics. Primitive types like Lua numbers translate cleanly to Terra `double` or `int`, and booleans map to `bool`. Lua strings are converted to `&int8` (`rawstring`). Lua tables can be converted into Terra structs or arrays if their structure matches. However, care must be taken with complex types: mismatched tables will cause runtime errors, and returning large structs by value to Lua results in a boxed LuaJIT `cdata` object.

### 4.2 Calling Lua from Terra

**CRITICAL:** It is *not* possible to directly evaluate arbitrary Lua code from within running Terra code. Terra compiles down to raw machine code that operates independently of the Lua runtime and garbage collector. The `[lua_expr]` escape syntax evaluates the Lua expression at *compile-time*, not runtime.

If you need to call Lua from Terra at runtime, you must use LuaJIT's FFI to cast a Lua function to a C function pointer using `terralib.cast(terra_function_type, lua_function)`. Because the Terra compiler cannot infer the return types of arbitrary Lua functions, **Lua functions cannot return values to Terra unless they are explicitly cast to a Terra function type.**

```lua
local function lua_add(x, y) return x + y end
-- Cast to a function taking two ints and returning an int:
local terra_add = terralib.cast({int, int} -> int, lua_add)

terra do_add()
    return terra_add(40, 2) -- Incurs FFI transition overhead
end
```

**WARNING:** Calling Lua from Terra is very slow compared to native execution because it forces a context switch out of the compiled machine code back into the Lua VM. Alternatively, you should precompute the required values in Lua and pass them as arguments to the Terra function, or use macros to evaluate logic at compile-time.

### 4.3 Passing Values Across the Boundary

When passing values across the boundary:

* **Primitives:** Numbers and booleans are passed by value (copied).
* **Strings:** Lua strings passed to Terra are converted to `&int8` pointers (`rawstring`). These pointers are only valid as long as the Lua string is not garbage collected. Terra `rawstring`s returned to Lua are wrapped in `cdata` pointers; they are *not* automatically converted back to Lua string objects. Use `ffi.string(ptr)` to convert them back.
* **Structs and Arrays:** Passing a Lua table to a Terra function expecting a struct or array creates a new, temporary C-allocated copy of the data. Returning a struct or array from Terra to Lua returns a boxed `cdata` object that references the memory. For performance, it is often better to allocate the struct in Lua using `terralib.new(MyStruct)` and pass a pointer (`&MyStruct`) to Terra.

### 4.4 Terra Functions as First-Class Lua Values

The declaration `terra myfunc() end` is syntactic sugar for `myfunc = terra() end`. Terra functions are Lua objects (tables with special metamethods). Because they are first-class values, you can store them in variables, place them in arrays, pass them as arguments to Lua functions, and return them from Lua functions. This is the foundation of Terra's generative programming.

These function objects expose a rich reflection API:

* `myfunc:compile()`: Forces the function to JIT compile.
* `myfunc:disas()`: Prints the LLVM IR and x86/ARM assembly for the function.
* `myfunc:printpretty()`: Prints a formatted textual representation of the Terra AST.
* `myfunc:getpointer()`: Returns a `cdata` function pointer that can be passed to C APIs expecting callbacks.

---

## 5. Types

### 5.1 Primitive Types

Terra provides a standard set of sized primitive types. Because Terra targets LLVM, the sizes of these types are exact and guaranteed, regardless of the underlying platform:

* **Signed Integers:** `int8`, `int16`, `int32`, `int64`. The `int` type is an alias for `int32`. The `long` type is an alias for `int64`.
* **Unsigned Integers:** `uint8`, `uint16`, `uint32`, `uint64`. The `uint` type is an alias for `uint32`.
* **Floating Point:** `float` (32-bit), `double` (64-bit).
* **Boolean:** `bool`.
* **Strings:** `rawstring` (an alias for `&int8`).
* **Special:** `opaque` (used for pointers to undefined structs, equivalent to `void*` in C), `niltype` (the type of the `nil` literal).
* **Pointers:** `intptr` and `ptrdiff` are sized to hold a pointer and the difference between two pointers on the target architecture.

### 5.2 The Type Hierarchy as Lua Values

In Terra, types themselves are first-class Lua values. For example, `int32` is simply a global Lua variable containing a Terra type object. Any expression following a colon `:` in a Terra variable declaration is evaluated as a Lua expression that must return a type object. Because types are Lua values, you can store them in variables (e.g., `local MyNum = double`), pass them as arguments to Lua functions, and return them. This is the mechanism Terra uses to achieve C++-style templating and generic programming: you simply write a Lua function that takes a type as an argument and returns a new Terra type or function.

### 5.3 Pointer Types

Pointer types are constructed using the `&T` syntax (e.g., `&int32` is a pointer to a 32-bit integer). In Lua code, `&T` is evaluated as a constructor that returns a pointer type object. In Terra code, `&` is the address-of operator (e.g., `&myvar`), while `@` is the dereference operator (e.g., `@myptr`).

Terra supports standard C-style pointer arithmetic. Adding an integer to a pointer advances it by the size of the underlying type. `&&T` represents a pointer to a pointer. The `nil` literal represents the null pointer and can be assigned to any pointer type. To express optional values safely, you typically use a pointer type and check against `nil`, though Terra does not enforce null-safety at compile time.

### 5.4 Array Types

Fixed-size array types are created using the `T[N]` syntax (e.g., `int[4]`), where `N` is a positive integer. Like C, Terra arrays are zero-indexed and stored entirely inline in memory (they are not pointers to heap allocations).

**CRITICAL DIFFERENCE FROM C:** In C, arrays naturally decay to pointers when passed to functions or assigned. In Terra, arrays are first-class value types. If you pass an `int[100]` to a function or assign it to another variable, Terra will perform a *full by-value copy* of all 100 elements. To avoid this overhead, you must explicitly pass arrays by pointer (e.g., `&int[100]`).

### 5.5 Vector Types

Terra provides first-class support for SIMD vector types via the `vector(T, N)` constructor, where `T` is a primitive scalar type (like `float` or `int32`) and `N` is the number of elements. These map directly to LLVM's underlying vector types.

When you perform arithmetic (`+`, `-`, `*`, `/`), logical operations, or comparisons on vectors, Terra automatically emits the corresponding vectorized SIMD instructions for your target architecture. To ensure optimal performance, `N` should be chosen based on the target hardware's vector register size (e.g., `vector(float, 4)` for 128-bit SSE, `vector(float, 8)` for 256-bit AVX).

### 5.6 Function Types

Function types are defined using the syntax `{T1, T2, ...} -> {R1, R2, ...}`. For single arguments or returns, the braces can be omitted (e.g., `int -> float`). Terra natively supports returning multiple values, so `{int, int} -> {float, bool}` is a valid function type. For functions that return no values (void), use the empty tuple type `{}` (e.g., `int -> {}`).

These type signatures are used to declare function pointers in Terra. Note that a Terra *function pointer* (a raw memory address pointing to executable code) is distinct from a Terra *function object* (a Lua table containing the AST and compilation state). You must compile a function object to get a function pointer.

### 5.7 Tuple Types

Tuples are special struct types that contain unnamed fields accessible via `_0`, `_1`, etc. They are created with `tuple(T1, T2, ...)`:

```lua
var a : tuple(int, float) = { 5, 3.14 }
-- Access fields via ._0, ._1
C.printf("%d %f\n", a._0, a._1)
```

Unlike regular structs, tuples with the same element types are considered the same type. Tuples are used internally for multiple return values and can be pattern-matched in assignments (`var x, y = my_multi_return_func()`).

### 5.8 Struct Types

Aggregate data types are created using the `struct` keyword in Lua. Terra uses a nominative type system, meaning every call to `struct` creates a unique type. Structs can be assigned a name (`struct MyStruct { ... }`) or created anonymously (`var a = { a = 1, b = 2.0 }`).

Terra guarantees that the memory layout of structs is strictly predictable and compatible with C's ABI by default, including standard padding for alignment. You can also explicitly specify `union` blocks within a struct to make multiple fields share the same memory location. More details on struct features are covered in [Section 10](#10-structs).

### 5.9 Type Introspection

Because types are Lua objects, they expose a rich introspection API. You can check the nature of a type using methods like `T:ispointer()`, `T:isarray()`, `T:isstruct()`, `T:isprimitive()`, and `T:isfunction()`. If you have a Terra value in Lua (a `cdata` object), you can retrieve its Terra type using `terralib.typeof(obj)`.

This introspection is the cornerstone of Terra's generic programming capabilities. For example, you can write a Lua function `print_any(T)` that uses `T:ispointer()` or `T:isstruct()` to programmatically generate a Terra function tailored to correctly print the internal layout of that specific type.

### 5.10 Syntax Precedence: Pointers and Arrays

**CRITICAL FOR C PROGRAMMERS:** Terra's type syntax is strictly compositional and evaluates left-to-right (or rather, inside-out based on Lua operator precedence), totally ignoring C's arcane declarator rules.

* `&int` evaluates to a Pointer to an Integer.
* `int[4]` evaluates to an Array of 4 Integers.
* `&int[4]` evaluates to a **Pointer to an Array** of 4 integers. (Because `int[4]` is evaluated first, then `&` is applied to the result).
* `(&int)[4]` evaluates to an **Array of 4 Pointers** to integers. (Because `&int` is evaluated first, then `[4]` is applied to the result).

Do not hallucinate C-style syntax like `int *x[4]` (which is a syntax error in Terra).

---

## 6. Variables and Scoping

### 6.1 var Declarations

Variables in Terra are introduced using the `var` keyword. You can declare a variable with an explicit type (`var x : int`), infer its type from an initializer (`var x = 5`), or provide both (`var x : int = 5`).

Terra supports multiple assignment on a single line: `var x, y = 1, 2` or `var x, y = f()` (where `f` returns multiple values).

**CRITICAL:** If a variable is declared without an initializer (`var x : int`), its initial value is *undefined* (it contains whatever garbage data was previously in that memory location). Terra does not zero-initialize variables by default to avoid performance overhead.

### 6.2 Scoping Rules

Terra variables are strictly block-scoped. A new scope is introduced by functions, `if` statements, loops, or explicitly using `do ... end` blocks. Variables declared within a block (including loop iterators) are destroyed when the block exits.

Terra's scoping integrates seamlessly with Lua's. When resolving an identifier inside a `terra` function, the compiler first checks the local Terra lexical scope. If not found, it checks the enclosing Lua lexical scope. If a Lua variable is found, it is captured by value at *compile-time* and effectively baked into the Terra code as a constant literal.

### 6.3 Global Variables

Global variables in Terra are created using the `global(type, [initial_value])` Lua function. This creates a Terra value that is shared across all compiled Terra functions, similar to a global variable in C.

You can declare them with an initial value (`my_global = global(int, 5)`). Globals are mutable by default and can be read/written by any Terra function. You can also specify that a global is constant by passing `true` as the `isconstant` flag. Additional parameters include `name` (for debugging), `isextern` (to bind to external symbols), and `addrspace` (LLVM address space).

**Global Variable Methods:**
* `globalvar:get()` - Gets the value as a LuaJIT `ctype` object.
* `globalvar:set(v)` - Sets the value from a Lua value.
* `globalvar:getpointer()` - Returns a `ctype` pointer to the global.
* `globalvar:gettype()` - Returns the Terra type.
* `globalvar:getname()` / `globalvar:setname(str)` - Get/set the debug name.
* `globalvar:setinitializer(init)` - Updates the initializer before compilation. Note that unlike C's `static` storage duration which limits visibility to a compilation unit, Terra globals are accessed directly via their Lua variable references, meaning their visibility is entirely controlled by Lua's scoping and module system.

### 6.4 Constants

Terra does not have a dedicated `const` keyword for local variables because Lua serves this exact role. Any Lua variable referenced inside a Terra function is evaluated when the function is defined and baked into the LLVM IR as a compile-time constant.

For more complex, structurally computed constants, you can use the escape operator `[expr]`. Whatever the Lua expression `expr` evaluates to (e.g., a precomputed lookup table or a mathematical constant) is spliced directly into the Terra AST. Additionally, Terra provides a `constant(expr)` API to create LLVM-level constant globals, which allows the LLVM optimizer to perform aggressive constant folding.

---

## 7. Expressions and Operators

### 7.0 Literals

Terra supports the following literal syntax:

* `3` - Integer literal (type `int`)
* `3.` - Double literal (type `double`)
* `3.f` - Float literal (type `float`)
* `3LL` - 64-bit integer literal (type `int64`)
* `3ULL` - 64-bit unsigned integer literal (type `uint64`)
* `"string"` or `[[multi-line]]` - String literal (type `&int8` / `rawstring`)
* `nil` - Null pointer (valid for any pointer type)
* `true` / `false` - Boolean literals (type `bool`)

### 7.1 Arithmetic and Logical Operators

Terra supports the standard set of C-like operators:

* **Arithmetic:** `+`, `-`, `*`, `/`, `%`. These follow C semantics; for integers, `/` truncates towards zero, and overflow wraps around silently.
* **Logical:** `and`, `or`, `not`. These operators *only* apply to `bool` types and exhibit short-circuit (lazy) evaluation.
* **Bitwise:** When applied to integer types, `and`, `or`, `not`, `^` (XOR), `<<`, and `>>` perform eagerly evaluated bitwise operations. Notice that `and`/`or`/`not` are overloaded based on operand type (logical for `bool`, bitwise for integers).

### 7.2 Comparison Operators

Terra provides the following comparison operators: `==`, `~=` (not equal), `<`, `>`, `<=`, `>=`. These evaluate to a `bool`.

Comparisons work naturally on primitive types and pointers (comparing memory addresses). 

**Null Checking:** Because there is no implicit cast to boolean, you **cannot** evaluate a pointer's truthiness directly. You must explicitly compare against `nil`:
* *Wrong:* `if ptr then ... end`
* *Wrong:* `if not ptr then ... end`
* *Right:* `if ptr ~= nil then ... end`
* *Right:* `if ptr == nil then ... end`

**Struct Comparison:** **Terra does not support direct structural comparison of arrays or structs by default**. This is intentional; since structs may contain padding, a simple bitwise memory comparison (like `memcmp`) might falsely report inequality. To compare custom structs, you must either write a specific comparison function or implement the `__eq` metamethod via the Exotype API (see Section 15).

### 7.3 The @ Dereference and & Address-Of

Terra uses `@` to dereference a pointer (e.g., `@ptr` yields the value the pointer points to). **Do not use `*` for dereferencing** (unlike C/C++).
Terra uses `&` to take the address of a variable (e.g., `&var` yields a pointer to `var`).

**Field Access on Pointers:** Unlike C/C++, **Terra does not have a `->` operator.** You use the standard dot `.` operator for both values and pointers. If `obj` is a pointer to a struct, `obj.field` implicitly dereferences the pointer (equivalent to `(@obj).field`).

**Unpacking Structs and Tuples:** Terra provides two built-in global macros, `unpackstruct(obj)` and `unpacktuple(obj)`. These take a struct or tuple object and expand its fields into a multiple-value expression list. This is extremely useful for generic metaprogramming or passing all fields of a struct as arguments to a function.

```terra
terra f() return {1, 2.5} end

terra g()
    var tup = f()
    var x, y = unpacktuple(tup)
    return x + y
end
```

**Important Asymmetry:** The `&` symbol serves dual purposes depending on context:

1. **In type declarations:** It is a type constructor. `var x : &int` declares a variable whose type is a pointer to an integer.
2. **In expressions:** It is the address-of operator. `x = &y` takes the memory address of `y`.
Because `&int` is also a valid Lua expression that evaluates to a Terra type, you must be careful with context to avoid confusing type constructors with operators.

### 7.4 Casts

Casts in Terra use a bracket syntax: `[TargetType](expression)`. For example, `[int32](3.14)` truncates a float to an integer. **Do not use C-style `(Type)val` or C++-style `Type(val)` casts**—those will cause syntax errors.

Terra supports standard explicit casts:

* Between numeric types (e.g., float to int, wide int to narrow int).
* Between pointers of different types (e.g., `[&int](ptr)`). This is critical for C FFI, where `void*` is translated to `&opaque` and must be explicitly cast.
* Between pointers and sufficiently large integers (e.g., `[intptr](ptr)` or `[&int](my_intptr)`).

**Crucially, Terra restricts implicit casts.** Unlike C, Terra will *not* implicitly convert a pointer to a boolean, or an `int` to a `bool`. You must explicitly cast `[bool](my_int)`. Furthermore, **Terra does not implicitly cast `void*` (`&opaque`) to other pointer types.** You must cast explicitly: `var ptr = [&int](C.malloc(sizeof(int)))`.

### 7.5 Sizeof

The `sizeof` operator (implemented internally as a built-in macro) returns the size in bytes of a type or an expression's type. It always evaluates to a compile-time constant.

You can use it with types directly, like `sizeof(int)`, or with expressions, like `sizeof(@myptr)`. This is essential for memory allocation, especially when writing generic Lua meta-programs. For example, when generating a generic array constructor, you can dynamically emit `C.malloc(N * sizeof(T))` where `T` is a type passed in from Lua.

---

## 8. Control Flow

### 8.1 if / elseif / else / end

Terra's `if` statements follow Lua's syntax:

```terra
if condition then
    -- ...
elseif other_condition then
    -- ...
else
    -- ...
end
```

**Strict typing:** The condition expression *must* evaluate to a `bool`. Unlike C, Terra will not implicitly convert a pointer or an integer to a boolean. `if ptr then` is a compile-time error; you must write `if ptr ~= nil then`. This strictness prevents subtle bugs related to truthiness.

### 8.2 Loops: while and repeat/until

Terra supports `while` loops (pre-condition) and `repeat ... until` loops (post-condition), mirroring Lua:

```terra
while a < 10 do
    a = a + 1
end

repeat
    a = a - 1
until a == 0
```

The condition is evaluated before every iteration in a `while` loop, and after every iteration in a `repeat` loop (ensuring the block executes at least once). You can exit any loop early using the `break` keyword. (Note: Terra does not have a `continue` keyword).

### 8.3 Loops: for (numeric)

Numeric `for` loops in Terra resemble Lua's syntax but differ crucially in indexing logic:

```terra
for i = 0, 10 do
    C.printf("%d
", i)
end
```

**IMPORTANT:** In Terra, the loop limit is *exclusive*. The loop above counts from 0 up to 9. This differs from Lua (which is inclusive) but is necessary because Terra uses 0-based pointer arithmetic and array indexing.

The loop accepts an optional third parameter for the step: `for i = 0, 10, 2 do`. The loop variable `i` is lexically scoped to the loop body and cannot be modified within the loop.

### 8.4 Loops: for (iterator)

Terra has experimental support for iterator-style `for` loops via the `__for` metamethod in exotypes. If a type implements this metamethod, you can write:

```terra
for i in Range {0, 10} do
    C.printf("%d
", i)
end
```

The `__for` metamethod is a Lua function invoked at compile-time. It takes the iterable object and a Lua callback function representing the loop body, and it returns a Terra quote that explicitly unrolls or generates the low-level loop structure (e.g., generating a `while` loop that calls a `next()` method).

### 8.5 switch Statements

**Experimental.** Terra provides a `switch` statement for branching on compile-time constant values:

```terra
switch expr do
    case 1 then
        first_thing()
    case 2 then
        second_thing()
    end
else
    default_thing()
end
```

Unlike C, `case` statements must be nested directly beneath `switch`, and no `break` statements are required (they are implicit). An optional `else` clause provides a default case.

### 8.6 goto and Labels

Terra supports `goto` and labels:

```terra
::loop::
C.printf("looping
")
goto loop
```

While discouraged in high-level programming, `goto` is essential in Terra because it is often used as a compiler backend. When writing Lua scripts that generate complex state machines, error-handling cleanup blocks, or custom control flow (like a DSL compiler), emitting a `goto` is frequently the most direct and efficient approach. Labels can also be generated dynamically using the Lua API (`terralib.label()`) and spliced in via escapes.

### 8.7 defer

Terra includes experimental support for the `defer` statement. `defer` schedules a function call to execute at the end of the current lexical block (when the scope exits via normal execution, `return`, or `break`).

```terra
var f = C.fopen("file.txt", "r")
defer C.fclose(f)
```

Deferred statements execute in LIFO (Last-In, First-Out) order. This provides a clean mechanism for RAII-style resource management. **Edge Case:** If you put a `defer` inside a loop, the deferred action occurs at the end of *that iteration's* block, not at the end of the enclosing function. It will execute repeatedly for every loop iteration.

### 8.8 return

The `return` statement immediately exits a function and provides a value to the caller. Terra natively supports returning multiple values, which are internally packed into an anonymous struct (a tuple).

```terra
return 1, true, 3.14
```

When returning large structs by value, Terra correctly adheres to the target platform's C ABI (handling hidden pointer arguments for large returns automatically). You can use early returns at any point in a block, and any scheduled `defer` statements in the current and enclosing blocks will be correctly executed before the function exits.

---

## 9. Functions

### 9.1 terra Function Declaration

A Terra function is declared using the `terra` keyword, specifying explicit types for all parameters and optionally the return type. If the return type is omitted, Terra infers it from the `return` statements.

```terra
terra add(a : int, b : int) : int
    return a + b
end
```

Because `terra` acts as an expression returning a function object, you can also define anonymous Terra functions directly: `local myfunc = terra(a: int) return a end`. This creates a Lua variable whose value is the uncompiled Terra AST.

### 9.2 Function Overloading

Unlike C++, Terra does not have native, implicitly resolved function overloading built into the core language syntax. Instead, overloading is achieved via the Lua API using `terralib.overloadedfunction(name, {func1, func2, ...})`.

When you call an overloaded function, Terra evaluates the types of the arguments provided at the call site and attempts to find a strictly matching signature among the provided functions. If it finds one, it statically dispatches to that specific function at compile time. Overloading is useful for providing a unified interface to operations that work on a fixed, known set of types. For truly generic algorithms (where the exact types are not known until the user requests them), using Lua functions that generate specialized Terra functions (templates) is preferred.

### 9.3 Multiple Return Values

Terra natively supports returning multiple values. The return type is defined as a tuple (e.g., `{int, float}`).

```terra
terra sort2(a : int, b : int) : {int, int}
    if a < b then return a, b else return b, a end
end
```

You can capture multiple returns via pattern matching: `var min, max = sort2(10, 5)`. If you do not provide enough variables to capture the returns, the excess values are silently discarded. Conversely, if you use a multi-return function as the *last* argument in another function call or return list, the tuple is "unpacked" and spliced directly into the argument list.

If you assign multiple returns to a single variable, it becomes a tuple:
```terra
var tup = sort2(10, 5)
C.printf("%d %d\n", tup._0, tup._1)

-- You can dynamically unpack it back into an expression list:
var x, y = unpacktuple(tup)
```

### 9.4 Varargs

Terra supports variadic functions (varargs) for interoperability with C functions like `printf`. While direct vararg syntax in Terra function definitions is limited, you can use macros to achieve similar functionality:

```lua
local printf = macro(function(...)
    local args = terralib.newlist{...}
    return `C.printf([args])
end)
```

When calling a C vararg function (imported via `includec`), Terra performs standard C ABI promotions (e.g., floats are promoted to doubles) before pushing the arguments onto the stack.

### 9.5 Methods and Self

Terra provides syntactic sugar for object-oriented method definitions using the colon `:` operator.

```terra
terra MyStruct:add(b : int)
    self.value = self.value + b
end
```

This automatically injects a `self` parameter as the first argument, with type `&MyStruct` (a pointer). When calling a method (`obj:add(5)`), if `obj` is a value rather than a pointer, Terra automatically takes the address of `obj` to pass to `self` (an implicit method receiver cast). Conversely, if the method expects a value (`self : MyStruct`) and you call it on a pointer, Terra will implicitly dereference the pointer (`@obj`).

If you explicitly define the method in the `.methods` table without the colon syntax, you can control whether `self` is passed by value or by pointer:
```terra
-- Takes 'self' by value (copies the struct)
terra MyStruct.methods.by_value(self : MyStruct) end

-- Takes 'self' by pointer (mutates the struct)
terra MyStruct.methods.by_ptr(self : &MyStruct) end
```

**IMPORTANT:** Method dispatch in Terra is entirely static. There is no built-in virtual dispatch or inheritance. If you need runtime polymorphism, you must build it manually by embedding function pointers within your struct (creating a vtable).

### 9.6 Inline Functions and Optimization Hints

Because Terra uses LLVM, it relies heavily on LLVM's powerful inlining passes during standard optimization (`-O3` equivalent). Most small functions will be aggressively inlined automatically.

If you need strict control, you can force inlining by calling `myfunc:setinlined(true)` on the Lua function object before compiling it. This attaches the `alwaysinline` attribute in LLVM. Conversely, `myfunc:setinlined(false)` prevents inlining. For accessing direct CPU instructions without function overhead, you can use `terralib.intrinsic("llvm.name", type)` to directly bind to LLVM built-in operations.

### 9.7 Recursion

Because Terra evaluates code eagerly during the Lua phase, a function must be declared before it can be referenced by another function. This creates an issue for mutual recursion. To resolve this, you must separate the declaration from the definition:

```terra
-- 1. Declare the type signature
terra isodd :: uint32 -> bool

-- 2. Define the first function
terra iseven(n : uint32) : bool
    if n == 0 then return true else return isodd(n - 1) end
end

-- 3. Define the second function
terra isodd(n : uint32)
    if n == 0 then return false else return iseven(n - 1) end
end
```

Alternatively, if definitions are placed immediately back-to-back with no intervening Lua statements, the parser processes them as a single block, implicitly handling the mutual references.

---

## 10. Structs

### 10.1 Basic Struct Declaration

Structs are the primary aggregate data type in Terra. They are defined outside of Terra code, acting as Lua statements that create type objects.

```lua
struct Point {
    x : float;
    y : float
}
```

Fields can be separated by either newlines or semicolons. 

**Struct Instantiation:** To create an instance of a struct, use curly brace syntax: `var p = Point { x = 1.0, y = 2.0 }` or ordered initialization `var p = Point { 1.0, 2.0 }`. **Do not use C++ style parenthesis initialization** (e.g., `Point(1.0, 2.0)` is a syntax error).
You can also define anonymous structs (tuples with named fields) using the constructor syntax without a type name: `var p = { x = 1.0, y = 2.0 }`.

**Field Access on Pointers:** Use the dot `.` operator for *both* value and pointer types. **Do not use the C/C++ `->` operator.**
```terra
var p = Point { 1.0, 2.0 }
var ptr = &p
C.printf("%f", ptr.x) -- Correct. Implicitly dereferences ptr.
-- C.printf("%f", ptr->x) -- ERROR: -> does not exist in Terra
```

If you have mutually recursive structs (like linked lists), you can use forward declarations by simply writing `struct Node` before providing the full definition later.

### 10.2 Memory Layout

Terra guarantees that struct field layout exactly matches the target platform's C Application Binary Interface (ABI). Fields are ordered in memory exactly as declared. The compiler automatically inserts padding bytes between fields to satisfy hardware alignment requirements (e.g., ensuring a 64-bit float sits on an 8-byte boundary).

Because Terra uses LLVM's data layout engine, a Terra struct can be safely passed by value or pointer to external C functions without any manual packing. You can verify memory layouts dynamically using the Lua API `terralib.offsetof(MyStruct, "fieldname")` or `terralib.sizeof(MyStruct)`.

### 10.3 Nested Structs

Structs can contain other structs. If a field's type is a struct (`box : BoundingBox`), the inner struct is stored *inline* by value, expanding the total size of the outer struct. If the field is a pointer (`child : &Node`), only the memory address is stored.

Terra also supports `union` blocks within a struct definition. All fields declared inside a `union { ... }` block will share the exact same starting memory address. The size of the union block is the size of its largest member.

When constructing or modifying a struct's `entries` programmatically from Lua, a union is represented as a nested list of fields:
```lua
MyStruct.entries = terralib.newlist({
    {"type_tag", int32},
    -- A nested list creates a union block
    { {"as_int", int64}, {"as_float", double}, {"as_ptr", &opaque} }
})
```

### 10.4 Struct Methods

When you define a struct, Terra automatically provisions a Lua table at `MyStruct.methods`. The syntax `terra MyStruct:do_thing()` is syntactic sugar that inserts a function into this table.

Because the methods table is just a Lua table, you can iterate over it, generate methods programmatically using loops and macros, or attach pure Lua functions to it. Static methods (methods that do not take a `self` instance) can be defined using dot syntax: `terra MyStruct.create_empty() ... end`.

### 10.5 Constructors and Destructors

Terra does not enforce C++-style constructors automatically. You can define regular methods (e.g., `init` and `free` or `destruct`) to handle initialization and cleanup.

However, it's vital to understand that Terra relies on explicit calls or `defer` for cleanup. If you implement a `free()` method, you must explicitly call it or write `defer obj:free()` when the object is instantiated. Because Terra uses by-value copying for struct assignment, implementing implicit destructors can easily lead to double-free bugs when a struct is passed to a function by value.

### 10.6 Struct Introspection

A defining feature of Terra is that you can introspect structs completely from Lua. The `MyStruct.entries` property contains a Lua list of all the fields and their associated Terra types.

By iterating over `MyStruct.entries` in Lua at compile-time, you can programmatically generate serialization routines, debug printers, or database ORM mappings that automatically adapt whenever fields are added or removed from the struct. This eliminates the need for external code generators or fragile macros.

### 10.7 Opaque Structs and Forward Declarations

To interoperate with C libraries that use opaque pointers (like `FILE*` or window handles), you can declare an incomplete struct in Terra: `struct OpaqueHandle`.

Terra allows you to create pointers to incomplete types (`var ptr : &OpaqueHandle`), pass them around, and return them. However, you cannot dereference them, allocate them by value, or query their `sizeof()`, because their internal memory layout is unknown to the compiler.

---

## 11. Pointers and Memory

### 11.1 Stack Allocation

In Terra, whenever you declare a local variable `var x : T`, the memory for `T` is allocated directly on the CPU execution stack. Its lifetime is strictly bound to the lexical scope of the declaration; when the scope ends, the memory is immediately reclaimed.

Crucially, Terra has no Garbage Collector and performs no escape analysis. If you return a pointer to a stack-allocated variable, or store that pointer in a long-lived structure, you will create a dangling pointer. The stack should be used for fixed-size, short-lived data, while the heap must be used for dynamically sized or long-lived data.

### 11.2 Heap Allocation

Terra does not provide built-in `new` or `delete` operators. To allocate memory on the heap, you must import the standard C library (`local C = terralib.includec("stdlib.h")`) and explicitly call `C.malloc` and `C.free`. Because `malloc` returns a `void*` (represented as `&opaque`), you must cast the result to your desired type:

`var my_struct = [&MyStruct](C.malloc(sizeof(MyStruct)))`

Remember that `C.malloc` returns `void*`, which in Terra is the type `&opaque`. You **must** use the explicit casting syntax shown above. Assigning `C.malloc` directly to a typed pointer without casting is a compile-time error.

Because manual memory management is verbose and error-prone, a common Terra idiom is to use Arena Allocators (bump allocators). Arenas are easily implemented in Terra and pair perfectly with its lack of constructors, allowing you to bulk-allocate and bulk-free memory for complex graph structures or compilation phases.

### 11.3 Pointer Arithmetic

Pointer arithmetic in Terra behaves exactly as it does in C. Adding an integer to a pointer (`ptr + 1`) advances the memory address by the size of the underlying type (`sizeof(@ptr)` bytes), not by 1 byte. Subtracting two pointers of the same type yields a `ptrdiff` integer representing the number of elements between them.

Pointer arithmetic is only safe when navigating within the bounds of a single, contiguously allocated block of memory (like an array). Attempting arithmetic on pointers to unrelated variables or stepping past the end of an array results in undefined behavior. You can use the `[intptr]` cast to bypass type-based arithmetic and manipulate raw memory addresses byte-by-byte if absolutely necessary.

### 11.4 Raw Memory Operations

For bulk memory manipulation, Terra relies on C's standard functions: `C.memcpy`, `C.memset`, and `C.memmove`. Terra assumes the programmer is responsible for verifying memory bounds before calling these functions.

To reinterpret the bits of one type as another (type-punning), you use Terra's explicit pointer casting (`[&float](int_ptr)`). Terra deliberately allows these unsafe, raw memory patterns because it is designed for low-level systems programming and writing runtime environments, where manipulating raw byte buffers and hardware registers is a fundamental requirement.

### 11.5 Memory Safety Patterns

While Terra provides no memory safety by default, you can use Lua metaprogramming to build your own safe abstractions with zero runtime cost in release builds. The most common pattern is creating a `SafeSlice(T)` exotype that stores a pointer and a length.

By leveraging Lua, you can conditionally compile bounds checks: if a global Lua variable `DEBUG_MODE` is true, the `SafeSlice:get(index)` method uses a macro to inject an `assert(index < self.length)`. In release builds, the macro omits the assert, leaving only the raw pointer access. This allows you to build memory-safe abstractions tailored to your specific project needs.

---

## 12. Arrays and Vectors

### 12.1 Fixed-Size Arrays

Fixed-size arrays (`T[N]`) are allocated contiguously. If declared as a local variable (`var arr : int[10]`), the entire array is allocated on the stack. You access elements using the standard bracket syntax `arr[i]`.

**Array Constructors:**
* `array(val1, val2, ...)` - Constructs an array from values, inferring the type.
* `arrayof(T, val1, val2, ...)` - Constructs an array of type `T[N]` where `N` is the number of values. Values are cast to `T` if needed.

```terra
var a = array(1, 2, 3, 4)        -- type: int[4]
var b = arrayof(int, 3, 4.5, 4)  -- type: int[3], 4.5 cast to int
```

**Copy Semantics:** Assigning an array or passing it to a function creates a full byte-for-byte copy. To avoid this, you should always pass arrays by pointer. You can get a pointer to the array using `&arr`, or a pointer to the first element using `&arr[0]`.

### 12.2 Array Idioms

To avoid expensive by-value copies, the standard idiom is to pass arrays to functions via pointer (`fn(&int[10])`). Because you cannot directly return a raw array from a function, the idiom is to wrap the array inside a struct (`struct Matrix { data : float[16] }`) and return the struct by value, or return a pointer to heap-allocated memory.

Terra supports multidimensional arrays (`float[4][4]`), which are guaranteed to be stored contiguously in row-major order (like C). This layout is critical for performance tuning: iterating over the inner-most dimension should correspond to the contiguous elements to maximize cache hits.

### 12.3 SIMD Vectors

Vectors like `vector(float, 4)` are Terra's primitive for SIMD programming.

**Vector Constructors:**
* `vector(val1, val2, ...)` - Constructs a vector, inferring element type.
* `vectorof(T, val1, val2, ...)` - Constructs a vector of element type `T`.

```terra
var a = vector(1, 2, 3, 4)           -- type: vector(int, 4)
var b = vectorof(int, 3, 4.5, 4)     -- type: vector(int, 3), 4.5 cast to int
```

Basic arithmetic (`+`, `-`, `*`, `/`) applied to vectors will automatically compile down to the appropriate hardware SIMD instructions (e.g., `addps` in SSE).

Elements can be extracted (`my_vec[0]`) or inserted (`my_vec[0] = 3.14`), but frequent scalar access to vectors defeats their performance purpose. Instead, you should load and store directly from memory using pointers: `@([&vector(float, 4)](float_ptr)) = my_vec`. While Terra does not provide a native shuffle operator, you can achieve specific swizzles by utilizing `terralib.intrinsic` to directly call the platform-specific LLVM shuffle or permute intrinsics.

### 12.4 Vector Programming Patterns

Achieving peak SIMD performance usually requires changing your memory layout from an Array of Structs (AoS) to a Struct of Arrays (SoA). For example, rather than an array of `Point {x, y, z}`, you use `struct Points { x: float[N], y: float[N], z: float[N] }`. This allows you to load contiguous blocks of `x` coordinates directly into a vector register.

While LLVM will attempt to auto-vectorize standard scalar loops if it can prove there is no pointer aliasing, explicitly writing your inner loops using Terra `vector` types guarantees vectorized execution. You can (and should) verify this by calling `:disas()` on your compiled function to ensure the output assembly contains vector instructions (e.g., `vaddps` instead of `addss`).

---

## 13. Quotes and Escapes: The Metaprogramming Primitives

### 13.1 The Quote Operator `

The backtick operator `` ` `` is used in Lua to create a *Quote*—a first-class Lua object representing a fragment of Terra Abstract Syntax Tree (AST). For example, `` `a + 1 `` returns a quote representing an addition expression. To quote an entire block of statements, use `quote ... end`.

Quotes are inert; the Terra code inside them is *not* evaluated or type-checked when the quote is created. They are simply data structures waiting to be spliced into a function. The type of a quote object in Lua is a special `terraquote` type, which exposes methods for reflection.

### 13.2 The Escape Operator []

The bracket operator `[ ]` is the *Escape*. When the Terra compiler parses a Terra function or quote, and encounters `[ lua_expr ]`, it pauses parsing, evaluates the Lua expression `lua_expr` in the local lexical environment, and splices the resulting Lua value directly into the Terra AST being built.

**CRITICAL TIMING DISTINCTION:** Escapes `[expr]` are evaluated exactly once when the Terra function is *defined* (parsed/constructed). In contrast, Macros (Section 14) are evaluated later, when the function is *compiled/type-checked*. 

Because escapes evaluate at definition time, if a Lua expression inside an escape refers to a local variable defined in the Terra code, that variable evaluates to a `Symbol` object in Lua, *not* a concrete runtime value.

```terra
terra foo(a : int)
    var b = 4
    -- 'a' and 'b' are Terra variables. Inside the escape, they are
    -- Lua variables holding Terra Symbol objects.
    return [ my_lua_generator(a, b) ]
end
```

The result of `lua_expr` must be convertible to a valid Terra AST node: a Terra primitive type (which splices as a type annotation), a number/string (which splices as a constant literal), a Terra Symbol (which splices as an identifier), or a Terra Quote (which splices as a block of code).

### 13.3 Types are Lua Expressions

In Terra, type annotations are *already* evaluated as Lua expressions. You do **not** need to use escapes `[]` for types. If you have a Lua variable `local T = float`, you simply write `var x : T`. The Terra compiler evaluates the expression `T` in the Lua environment and uses the resulting type.

This means any valid Lua expression can appear after a colon: `var x : MyTypeGenerator(int, 5)`. This is the primary mechanism for generic programming, acting as a highly flexible, imperative alternative to C++ templates. You only use the `[expr]` escape syntax to splice *values* or *quotes* into executable Terra code, not for type annotations.

### 13.4 Splicing Values

When a standard Lua value (like `5` or `"hello"`) is returned by an escape, it is hardcoded into the resulting LLVM IR as a compile-time constant literal. For instance, if `local N = 10`, the Terra code `return [N * 2]` compiles exactly the same as `return 20`.

This is fundamentally different from a runtime variable: changing the value of the Lua variable `N` *after* the Terra function has been compiled will have zero effect on the compiled machine code. The value is permanently baked in during the AST construction phase.

### 13.5 Splicing Quotes

If a Lua expression inside an escape evaluates to a Quote object, the AST represented by that quote is seamlessly grafted into the surrounding AST. This allows for powerful code generation. You can construct an array of quote objects in Lua using a loop, and then dynamically assemble them into a larger Terra function. For example, you can write a Lua recursive function that builds a deeply nested mathematical expression as a single Quote, and then splice that final Quote into a Terra `return` statement.

### 13.6 Splicing Statement Lists

If an escape evaluates to a Lua table (specifically a `terralib.newlist()`) containing multiple Quote objects, Terra performs an unquote-splice, unrolling the list and inserting every quote sequentially into the AST. This is how you programmatically generate sequential blocks of statements.

For instance, if you want to explicitly unroll a loop 4 times, you can use Lua to generate 4 `quote ... end` blocks, store them in a `newlist`, and then place an escape `[my_list]` in your Terra code:

```lua
local stmts = terralib.newlist()
for i = 1, 4 do
    stmts:insert(quote C.printf("Unroll %d\n", i) end)
end

terra do_unroll()
    [stmts] -- Splices all 4 printf statements sequentially
end
```

### 13.7 The exprlist Pattern

The unquote-splice behavior also works for comma-separated expression lists, such as function arguments. If you have a Lua list of quoted expressions `args = { \`a, \`b, \`c }`, you can call a Terra function using an escape: `my_func([args])`.

The compiler automatically flattens the list into `my_func(a, b, c)`. This pattern allows you to write Terra functions that are effectively variadic; the Lua meta-program inspects the context, builds a dynamic array of arguments, and splices them into the function call at compile time.

### 13.8 Hygiene and Programmatic Symbols

When generating code, you often need to introduce temporary variables. If you simply write `quote var temp = ... end`, you risk **variable capture**—if the code you are splicing already uses the name `temp`, your generated code will collide with it or shadow it unpredictably.

Terra solves this using the `symbol()` API. A symbol is a guaranteed-unique identifier. 

```lua
local function make_swap(a_quote, b_quote)
    -- We must pass the Terra type to symbol() if we want it strictly typed,
    -- or omit it if we want Terra to infer it from the initializer.
    local temp = symbol(a_quote:gettype(), "temp_swap_var")
    
    return quote
        -- Use the escape operator to declare the variable using the symbol
        var [temp] = a_quote
        a_quote = b_quote
        b_quote = [temp]
    end
end
```

Whenever you generate declarations (`var [sym]`, `goto [lbl]`, `::[lbl]::`), you must use escapes to inject the programmatic symbol or label object.

---

## 14. Macros

### 14.1 What Terra Macros Are

A Terra macro is a Lua function invoked at *type-checking time* (phase 2), rather than AST construction time (phase 1). They look like regular function calls in Terra but are defined in Lua using `mymacro = macro(function(arg1, arg2) ... end)`.

Unlike C macros, which are blind text replacements, Terra macros receive the actual AST nodes (Quotes) of their arguments. They are fully hygienic by default, have access to the type information of their arguments, and can leverage the full computational power of Lua to analyze the types and generate a customized Quote to replace the macro call.

*(Note: The `macro` API automatically strips the compiler context from the arguments. If you specifically need access to the compilation context to emit custom compiler errors, use `terralib.internalmacro(function(ctx, tree, arg1, arg2) ... end)` instead).*"

### 14.2 Macro Parameters

When a macro is invoked, the parameters are the arguments passed to the macro in Terra.

**Crucially, these arguments are typed AST nodes (Quotes), not runtime values.** You cannot do `if arg == 5` because `arg` is an AST node. Instead, you use the introspection API: `arg:gettype()` returns the Terra type of the node. If the node is a compile-time constant, you can extract its value using `arg:asvalue()`. The macro must analyze these properties and return a new Quote.

### 14.3 Hygiene

Terra quotes are hygienic; variables referenced within a quote bind strictly to their lexical environment, preventing the "variable capture" bugs common in C macros. However, when writing a macro that evaluates an argument multiple times, you must manually avoid double-evaluation side-effects.

To safely store an argument in a temporary variable, you use `symbol()` to generate a guaranteed-unique identifier in Lua. The pattern is:

```lua
local tmp = symbol(arg:gettype())
return quote var [tmp] = arg in [tmp] * [tmp] end
```

This ensures the expression `arg` is evaluated only once, safely bound to a unique name, and reused.

### 14.4 Macros vs Functions

Use a Terra function when you need standard runtime execution and strict, predefined types. Use a Macro when you need polymorphism, conditional code generation, or to bypass Terra's strict type system.

Because macros run at compile time, they incur zero runtime overhead—the generated code is spliced directly in place. Macros can inspect the `gettype()` of their arguments and emit entirely different LLVM instructions for floats versus integers. They can also generate control flow (like `defer` or custom loops) that is impossible to express as a standard function call.

### 14.5 Macro Patterns

Common macro patterns include:

**Polymorphic Math**
A `max` macro that checks `a:gettype()`, creates unique symbols for `a` and `b` to prevent double-evaluation, and emits an inline `if/else` quote:

```lua
local max = macro(function(a, b)
    local ta, tb = a:gettype(), b:gettype()
    assert(ta == tb, "max expects identical types")
    local va, vb = symbol(ta), symbol(tb)
    return quote
        var [va], [vb] = a, b
        in [va] > [vb] and [va] or [vb]
    end
end)
```

**Zero-cost Abstractions**
An `assert(cond)` macro that checks a global Lua `DEBUG` flag. If false, it returns an empty quote. If true, it emits the bounds check and `abort()`.

```lua
local C = terralib.includec("stdlib.h")
local DEBUG = true
local assert = macro(function(cond)
    if not DEBUG then return quote end end
    return quote
        if not cond then C.abort() end
    end
end)
```

**Type Dispatch**
A generic C++ style `new` allocator:

```lua
local new = macro(function(typquote)
    local typ = typquote:astype()
    return `[&typ](C.malloc(sizeof(typ)))
end)
-- Usage: var ptr = new(int)
```

**Programmatic Operator Application**
Terra provides a built-in macro `operator(op_string, ...args)` that allows you to dynamically emit operations (e.g., `+`, `-`, `<`, etc.) when the operator itself is a variable in your meta-program:

```lua
local op = "+"
local add_macro = macro(function(a, b)
    return quote var x = operator(op, a, b) in x end
end)
```

### 14.6 Internal Macros and Error Reporting

Standard macros defined via `macro(function(...) ... end)` only receive the AST nodes of their arguments. If your macro needs to perform semantic validation and reject invalid code gracefully (pointing the error at the exact line of the macro invocation), you must use `terralib.internalmacro`.

`terralib.internalmacro` passes two hidden arguments before the macro arguments:
1. `ctx`: The compilation diagnostics context.
2. `tree`: The AST node representing the macro invocation site itself.

```lua
local safe_div = terralib.internalmacro(function(ctx, tree, a, b)
    if b:asvalue() == 0 then
        -- This throws a compile-time error pointing EXACTLY 
        -- at the line in the .t file where safe_div was called!
        ctx:reporterror(tree, "Division by zero detected at compile time!")
        return tree:aserror() -- Gracefully poison the AST
    end
    return `a / b
end)
```
This is the required pattern for building robust, safe DSLs and libraries that provide high-quality developer feedback.

---

## 15. Exotypes: Operator Overloading and Metamethods

### 15.1 What Exotypes Are

Exotypes are Terra structs augmented with a Lua `metamethods` table (`MyStruct.metamethods`). This table contains Lua functions that define the struct's behavior when it interacts with built-in Terra operators, similar to Lua's metatable system or C++ operator overloading.

When the Terra typechecker encounters an operation on an exotype (like `a + b`), it pauses and invokes the corresponding Lua metamethod. That Lua function must return a Terra Quote containing the generated AST to implement the operation. This allows you to define complex, staged behaviors with zero runtime overhead.

### 15.2 Arithmetic Metamethods

You can overload arithmetic operators using `__add` (+), `__sub` (-), `__mul` (*), `__div` (/), `__mod` (%), and `__unm` (unary -).

These metamethods can be implemented in two ways:
1. **As a Terra function:** This is the easiest method. The function takes the concrete types and returns the result.
2. **As a Lua macro:** The macro receives the AST nodes (Quotes) of the operands and must return a Quote.

```lua
struct Complex { real : float, imag : float }

-- Method 1: As a Terra function (Recommended for simple overloads)
terra Complex.metamethods.__add(a : Complex, b : Complex)
    return Complex { a.real + b.real, a.imag + b.imag }
end

-- Method 2: As a Lua macro returning a Quote
Complex.metamethods.__sub = macro(function(a_quote, b_quote)
    return `Complex { a_quote.real - b_quote.real, a_quote.imag - b_quote.imag }
end)
```

### 15.3 Comparison Metamethods

Comparison operators are overloaded via `__eq` (==), `__ne` (~=), `__lt` (<), `__le` (<=), `__gt` (>), and `__ge` (>=). The metamethod signature is identical to arithmetic operators. The returned Quote must evaluate to a `bool`.

### 15.4 Index and Newindex

Custom array or property indexing is handled by `__index` (for reading) and `__newindex` (for writing). Uniquely, `__index` can handle both `obj[i]` and `obj.field` missing accesses.

This is ideal for implementing bounds-checked arrays. In `__index(self, obj_ast, index_ast)`, you can inspect the `index_ast`. If it is a compile-time constant (`index_ast:asvalue()`), you can perform bounds checking immediately in Lua and throw a compilation error. If it's a runtime variable, you can emit a Quote that includes a runtime bounds check and panic.

### 15.5 __apply: Making Structs Callable

The `__apply` metamethod allows an instance of a struct to be invoked like a function: `my_obj(arg1, arg2)`. The metamethod signature is `__apply(self, obj_ast, ...args_asts)`.

This is the Terra equivalent of C++ functors or closures. It allows you to package state (within the struct fields) and behavior (via `__apply`). It is extensively used when writing DSLs for lazy evaluation, where an object represents a deferred computation that is only realized when explicitly called.

### 15.6 __cast: Implicit Conversion

The `__cast` metamethod defines how your type converts to or from other types. It is invoked when the compiler encounters a type mismatch. The signature is `__cast(from_type, to_type, exp_ast)`.

For example, if you define a `Complex` struct, you can implement `__cast` to intercept conversions where `from_type` is a float and `to_type` is `Complex`, allowing you to seamlessly use floats where a `Complex` is expected.

```lua
Complex.metamethods.__cast = function(fromtype, totype, exp)
    if fromtype == float and totype == Complex then
        return `Complex { exp, 0.f }
    end
    error("invalid conversion")
end
```

### 15.7 No Implicit RAII Metamethods

**Note:** Terra does *not* provide `__init` or `__destruct` metamethods that are automatically called when a variable enters or exits scope. While you can define regular methods for cleanup, Terra's philosophy avoids hidden control flow. If a type provides a `destruct` method, it is the programmer's explicit responsibility to call it, typically by using the `defer` statement: `var obj = MyType.alloc(); defer obj:destruct()`.

Because Terra uses raw by-value copying, implicit destructors would be disastrous: passing an object to a function by value would copy it, and if a destructor fired automatically at the end of that function, it would free the memory while the original caller still held a pointer. Therefore, RAII is strictly manual via `defer`.

### 15.8 __getmethod: Dynamic Method Dispatch

When the compiler encounters `obj:method()`, it looks in `obj.methods`. If the method isn't there, it calls `__getmethod(self, methodname)` or `__methodmissing`.

This is one of Terra's most powerful metaprogramming features. `__methodmissing` can dynamically inspect the `methodname` string and programmatically generate a Terra function or macro on the fly to satisfy the request. For example, a Proxy type that forwards method calls to its elements:

```lua
local function Array(T)
    local struct ArrayImpl { data : &T, N : int }
    ArrayImpl.metamethods.__methodmissing = macro(function(methodname, selfexp, ...)
        local args = terralib.newlist {...}
        return quote
            var self = selfexp
            for i = 0, self.N do
                self.data[i]:[methodname]([args])
            end
        end
    end)
    return ArrayImpl
end
```

### 15.9 Lazy Layout and Initialization: __getentries and __staticinitialize

When defining extremely complex or self-referential Exotypes (like an automated Object-Relational Mapper or a UI layout system), you may not know the exact fields of a struct until it is actually used.

Terra supports lazy struct layout via `__getentries(self)`. If defined, the compiler calls this Lua function exactly *once*, the first time the struct's size or layout is needed (e.g., when it is allocated, or when `sizeof` is called). It must return a Lua list of field entries.

```lua
local struct DynamicEntity
DynamicEntity.metamethods.__getentries = function(self)
    -- Compute fields dynamically...
    return terralib.newlist({
        { field = "id", type = int32 },
        { field = "name", type = rawstring },
        -- A nested list defines a union block
        { { field = "as_int", type = int }, { field = "as_float", type = float } }
    })
end
```

Immediately after the layout is finalized, Terra calls `__staticinitialize(self)`. This is the perfect place to build Virtual Method Tables (vtables) or perform reflection across the newly finalized fields (`self:getentries()`), because the struct type is now considered complete.

### 15.10 Custom Type Names: __typename

To override how a dynamically generated struct prints in compiler error messages or `tostring()`, define `__typename(self)`:

```lua
DynamicEntity.metamethods.__typename = function(self)
    return "DynamicEntity_Custom"
end
```

---

## 16. Environments and Symbol Resolution

### 16.1 Default Symbol Resolution

When Terra parses an identifier, it resolves it in phases. First, it checks the local lexical scope of the Terra function (e.g., local variables and parameters). If the identifier is not a Terra local, the compiler falls back to the *environment table* bound to that code chunk.

By default, this environment table is the surrounding Lua lexical scope (including the `_G` global table). This is why C functions imported via `local C = terralib.includec(...)` are immediately visible in Terra: the compiler simply queries the Lua environment, finds the `C` table, and resolves the function.

### 16.2 Custom Environments

You can override the default symbol resolution by providing a custom environment table to `terralib.loadstring` or `terralib.loadfile`, using Lua's standard `setfenv` or `_ENV` semantics (depending on the Lua version).

By passing a restricted table, you can completely sandbox the Terra compilation. The compiled Terra code will only have access to the exact types, globals, and C functions you explicitly placed in that table. This is the foundational pattern for building secure DSLs where users are prevented from calling arbitrary system functions like `C.system` or `C.malloc`.

### 16.3 Environment Composition

Because environments are just Lua tables, you can compose them using Lua's `__index` metamethod. You can create a layered symbol table where a sandboxed DSL environment inherits from a safe subset of the global environment.

```lua
local dsl_env = { Math = terralib.includec("math.h") }
setmetatable(dsl_env, { __index = safe_globals })
```

This approach allows you to inject DSL-specific keywords and types at the top level while gracefully falling back to approved standard libraries, giving you absolute control over the DSL's namespace.

### 16.4 Environments for Safety

Custom environments are the primary tool for enforcing safety policies in Terra DSLs. Because Terra itself lacks borrow checkers or memory safety guarantees, you enforce safety by hiding the unsafe tools.

By omitting `C.malloc`, `C.free`, and `terralib.cast` from the custom compilation environment, you physically prevent the DSL user from executing raw memory manipulation. Instead, you inject your own safe allocator functions and bounds-checked Array types into the environment. The resulting Terra code is forced to be safe because the unsafe primitives literally do not exist in its symbol table.

---

## 17. The terralib API

### 17.1 Core Compilation Functions

The core API for loading Terra code matches Lua's.

* `terralib.loadstring(code, [name, env])`: Compiles a string of mixed Lua/Terra code. Returns a Lua chunk function. If there is a syntax error, it returns `nil` and the error message.
* `terralib.loadfile(filename, [env])`: Like `loadstring` but reads from a file.
* `require(module)`: A drop-in replacement for Lua's `require` that also supports loading `.t` (Terra) files (Terra adds a loader to `package.loaders`).
Calling the resulting chunk function actually executes the top-level Lua code, which defines the Terra functions and types within the environment.

### 17.2 Type Constructors

While you can use syntax like `&int` in Terra, you can also construct types programmatically in Lua using the `terralib.types` API:

* `terralib.types.pointer(T, [addrspace])`: Returns a pointer to type `T`. Optional address space for LLVM address spaces.
* `terralib.types.array(T, N)`: Returns a fixed-size array of `T`.
* `terralib.types.vector(T, N)`: Returns a SIMD vector of `T`.
* `terralib.types.newstruct(name)`: Creates a new, incomplete struct type.
* `terralib.types.tuple(T1, T2, ...)`: Creates a tuple type.

These API calls are essential when writing Lua metaprograms that need to dynamically assemble complex types based on runtime data.

**List Type:**
Terra includes a `List` type (`require("terralist")`) used for metaprogramming. Lists extend Lua tables with functional methods like `map`, `filter`, `fold`, etc. API functions returning arrays (e.g., `fn:getdefinitions()`, `type.parameters`) return List objects.

### 17.3 Function Manipulation

Terra function objects expose a rich API:

* `myfn:compile()`: Forces the immediate JIT compilation of the function. Ensures all dependencies are valid.
* `myfn:disas()`: Dumps the LLVM IR and architecture-specific assembly to standard output.
* `myfn:printpretty()`: Prints the typed, resolved AST of the function.
* `myfn:gettype()`: Returns the function's type signature.
* `myoverload:getdefinitions()`: Returns a list of all concrete Terra functions registered under an overloaded function object.

### 17.4 Saving Compiled Code

To compile Ahead-Of-Time, use `terralib.saveobj(filename, {name = func}, args)`.

The second argument is a table mapping exported C-symbol names to Terra functions. The `args` table specifies the output format. You can output native executables, shared libraries (`.so`/`.dylib`), object files (`.o`), LLVM bitcode (`.bc`), or LLVM IR (`.ll`).

Generating object files allows you to link Terra code into standard C/C++ build systems (like CMake). Generating LLVM bitcode is the standard pipeline for targeting WebAssembly via Emscripten.

### 17.5 Linking

When running in JIT mode, if you import C headers via `includec` that rely on external libraries, you must load the corresponding dynamic libraries using `terralib.linklibrary("libfoo.so")`. This exposes the symbols to the LLVM JIT execution engine.

When compiling AOT via `saveobj`, `linklibrary` does not bake the library into the object file. You are simply generating `.o` files containing undefined symbol references. You must instruct your system linker (e.g., `gcc` or `ld`) to link the final binary against those libraries.

### 17.6 Symbol and Quote Utilities

The `terralib` namespace provides predicates to identify AST nodes and Terra objects during metaprogramming:

* `terralib.istype(t)` / `terralib.types.istype(t)`
* `terralib.isfunction(f)`
* `terralib.isquote(q)`
* `terralib.issymbol(s)`
* `terralib.isglobalvar(g)`
* `terralib.ismacro(m)`
* `terralib.islabel(l)`
* `terralib.isoverloadedfunction(f)`
* `terralib.isconstant(c)`
* `terralib.islist(l)`

**Memoization:**
* `terralib.memoize(fn)` - Wraps a function to cache its results based on arguments. Essential for generic type constructors to ensure `Vector(float) == Vector(float)`.

**Labels:**
* `terralib.label([displayname])` - Creates a new unique label for use with `goto`. Returns a label object that can be spliced into Terra code via `::[mylabel]::` and `goto [mylabel]`.

**Lists:**
* `terralib.newlist([table])` - Creates a Terra List object. This extends a standard Lua table with functional methods. It is the standard collection type used pervasively throughout the Terra compiler and metaprogramming APIs. Useful methods include:
  * `list:insert(v)` / `list:insertall(other_list)`
  * `list:map(fn)`: Returns a new list with `fn` applied to each element. `fn` can be a function or a string (representing a method name or field to extract).
  * `list:mapi(fn)`: Like `map`, but `fn` receives `(index, value)`.
  * `list:filter(fn)`: Returns a list containing only elements where `fn` returns true.
  * `list:reduce(fn)` / `list:fold(init, fn)`: Standard functional reductions.

**Version and Diagnostics:**
* `terralib.printversion()` - Prints diagnostic information about Terra version, LLVM version, and target architecture.

You use `symbol(type, [name])` to generate unique, hygienic identifiers for use inside quotes. This is critical for avoiding variable capture when generating code. Note that `symbol()` creates variable identifiers, while `terralib.label()` creates control-flow destinations; they are distinct types.

### 17.7 Memory and Value Utilities

**FFI Wrappers:**
* `terralib.new(terratype, [init])` - Allocates a new object with Terra type (wrapper around LuaJIT's `ffi.new`). The object is garbage collected when no longer reachable from Lua.
* `terralib.cast(terratype, obj)` - Converts an object to a Terra type using FFI conversion rules.
* `terralib.typeof(obj)` - Returns the Terra type of a LuaJIT `ctype` object.

**Memory Operations:**
* `terralib.attrload(addr, attrs)` - Performs a load with attributes (`nontemporal`, `align`, `isvolatile`).
* `terralib.attrstore(addr, value, attrs)` - Performs a store with attributes.
* `terralib.select(cond, val1, val2)` - Built-in macro for conditional selection (like C's ternary operator).

**External Symbols:**
* `terralib.externfunction(name, type)` - Creates a Terra function bound to an external symbol (e.g., `terralib.externfunction("atoi", {rawstring} -> {int})`).
* `terralib.linkllvm(filename)` - Links an LLVM bitcode file (`.bc`), allowing inlining across module boundaries.

### 17.8 Intrinsics

To access low-level CPU features not exposed by Terra syntax, use `terralib.intrinsic("llvm.intrinsic.name", TypeSignature)`. This binds directly to an LLVM built-in intrinsic.

```lua
local sqrt = terralib.intrinsic("llvm.sqrt.f32", float -> float)
```

Common uses include math operations (`llvm.fma`), memory manipulation (`llvm.prefetch`), and platform-specific SIMD instructions (like `llvm.x86.avx.dp.ps.256`). You must consult the official LLVM Language Reference Manual for your specific LLVM version to find the exact naming conventions and type signatures for these intrinsics.

### 17.9 Atomic Operations and Memory Barriers

Terra provides low-level atomic operations matching LLVM's concurrency model:

* `terralib.atomicrmw(op, ptr, val, {ordering = "seq_cst", align = n, isvolatile = false})`: Performs an atomic Read-Modify-Write. Supported ops include `add`, `sub`, `and`, `or`, `xor`, `xchg`, `min`, `max`, `fadd`, `fsub`.
* `terralib.cmpxchg(ptr, cmp, new_val, {success_ordering = "seq_cst", failure_ordering = "seq_cst", align = n, isvolatile = false, isweak = false})`: Performs an atomic compare-and-exchange. Returns a tuple `{old_value, success}`.
* `terralib.fence({ordering = "seq_cst", syncscope = ""})`: Issues a memory fence/barrier to prevent reordering of atomic instructions.

Memory orderings must be specified explicitly (`"relaxed"`, `"acquire"`, `"release"`, `"acq_rel"`, `"seq_cst"`). These map directly to the corresponding barrier instructions on the target hardware (e.g., `LOCK` prefixes on x86, `DMB` on ARM).

### 17.10 Inline Assembly

Terra provides direct support for LLVM inline assembly via the built-in `terralib.asm` macro. This allows you to emit raw architecture-specific instructions.

* `terralib.asm(return_type, asm_string, constraints, is_volatile, ...args)`

```terra
terra add_one(a : int)
    -- Adds 1 to 'a' using x86 assembly.
    -- "=r" means return in a register, "0" means input shares the same register as output 0.
    return terralib.asm(int, "addl $$1, $1", "=r,0", true, a)
end
```
*Note: The constraints string uses standard LLVM/GCC inline assembly constraint formatting.*

### 17.11 CUDA and GPU Compilation

Terra has built-in, first-class support for compiling kernels to NVIDIA PTX via `cudalib`. (Ensure `TERRA_ENABLE_CUDA` is on during build).

* `terralib.cudacompile(module_table, [dump_ptx])`: Takes a table of Terra functions and compiles them to PTX.
* `cudalib.nvvm_read_ptx_sreg_tid_x()`: Intrinsic to get thread ID.
* `cudalib.sharedmemory(Type, N)`: Allocates `__shared__` memory.

```lua
local cudalib = require("cudalib")
local tid_x = cudalib.nvvm_read_ptx_sreg_tid_x

local terra my_kernel(data : &float)
    var idx = tid_x()
    data[idx] = data[idx] * 2.0
end

-- Compile the kernel
local compiled = terralib.cudacompile({ my_kernel = my_kernel })

terra run_kernel(data_ptr : &float)
    -- Launch parameters: Grid X,Y,Z, Block X,Y,Z, Shared Mem, Stream
    var launch_params = terralib.CUDAParams { 1, 1, 1, 256, 1, 1, 0, nil }
    compiled.my_kernel(&launch_params, data_ptr)
end
```

### 17.12 Targets

Terra supports cross-compilation by instantiating explicit target objects: `local target = terralib.newtarget({Triple = "wasm32-unknown-unknown"})`.

You can specify the `CPU` (e.g., `"skylake"`) and specific LLVM `Features` (e.g., `"+avx2,-fma"`). You can pass this target object as an argument to `saveobj` or `includec`. `terralib.hosttarget` provides the default target representing the current machine. Because targets are encapsulated objects, a single Lua script can generate Terra code, instantiate multiple targets, and compile the exact same codebase for Windows, Linux, macOS, and WebAssembly simultaneously.

---

## 18. C Interop

### 18.1 terralib.includec() and No Standard Library

**Terra does not have a built-in standard library.** There is no `print`, `malloc`, or `math` module native to Terra code. Instead, you access the standard C library using C interop.

The `terralib.includec("header.h")` function is the gateway to C interop. Internally, Terra invokes the Clang compiler frontend to parse the C header file. Clang resolves all `#include` directives, macros, and type definitions using the host system's standard C search paths.

**WARNING ON C++:** `includec` uses Clang's **C frontend**, not C++. It cannot parse C++ classes, templates (`std::vector`), namespaces, or function overloading. If you must interop with a C++ library, you must write a `extern "C"` wrapper API in C++, compile it to a shared library, and `includec` the C-compatible wrapper header.

```lua
local C = terralib.includec("stdio.h")
local stdlib = terralib.includec("stdlib.h")

terra my_func()
    C.printf("Hello World\n")
    var ptr = [&int](stdlib.malloc(sizeof(int) * 10))
end
```

The function returns a Lua table that acts as a namespace. If the header defined `int foo();` and `typedef int my_int;`, the resulting Lua table `C` will contain `C.foo` (a Terra function object) and `C.my_int` (a Terra type object). You can pass additional arguments to Clang, such as `-I/custom/path` or `-DDEBUG=1`, as trailing arguments to `includec`.

### 18.2 What Gets Imported

When `includec` parses a header into a Lua table (e.g., `local C = terralib.includec(...)`):

* **Functions** become Terra function objects ready to be called (e.g., `C.printf`).
* **Structs** become Terra struct types (with exact C layout matching). Note that in Terra, you access them via the namespace table without the `struct` keyword: `var s : C.tm` (not `struct C.tm`).
* **Typedefs** are resolved to their underlying Terra types.
* **Enums** are imported as simple integer constants in the Lua table.
* **Simple Macros** (e.g., `#define MAX_SIZE 100`) are evaluated and imported as Lua numbers.
* **Function-like Macros** (e.g., `#define MAX(a,b) ((a)>(b)?(a):(b))`) are **NOT** imported, because they are preprocessor directives, not actual C functions or AST nodes.

### 18.3 Function Macros and Inline Functions

Because function-like macros and certain `static inline` functions do not produce externally linkable symbols, `includec` cannot always provide callable Terra bindings for them.

The standard workaround is twofold: either re-implement the macro logic natively as a Terra macro or inline Terra function, or create a tiny C wrapper file that defines a standard, non-inline C function that calls the macro/inline function, and then `includec` that wrapper file instead.

### 18.4 ABI Compatibility

Terra is designed for strict Application Binary Interface (ABI) compatibility with C. Terra functions use the standard C calling convention (`cdecl`) by default. Terra structs align their fields exactly as a C compiler would on the target architecture. This means you can freely pass pointers to Terra structs into C functions, or pass C structs into Terra functions.

**Exceptions:** Terra does not currently support C bitfields. Additionally, while Terra can *call* C functions that use `varargs` (`...`), it handles the ABI promotion rules automatically, but complex vararg interactions across module boundaries require careful type casting.

### 18.5 Pointers, void*, and Array FFI Gotchas

When calling C functions from Terra, LLMs frequently hallucinate C semantics that violate Terra's strict type system. Keep these rules in mind:

*   **`void*` is `&opaque`:** C functions that return or accept `void*` will have the Terra type `&opaque`. You **must explicitly cast** pointers using the `[Type](value)` syntax.
    *   *Wrong:* `var p : &int = C.malloc(sizeof(int))`
    *   *Right:* `var p = [&int](C.malloc(sizeof(int)))`
*   **Strings are `&int8`:** C functions taking `char*` or `const char*` expect a Terra `&int8` (also aliased as `rawstring`). Terra string literals (`"hello"`) natively evaluate to `&int8` and can be passed directly.
*   **Out Parameters (Pass-by-Reference):** To pass a value by reference to a C function, you must allocate it on the stack using `var` and pass its address using `&`.
    *   *Right:* `var out_val : int; C.some_c_func(&out_val); return out_val`
*   **Arrays do NOT decay to pointers:** In C, passing an array `int arr[5]` to a function expecting `int*` implicitly decays the array to a pointer. **Terra does not do this implicitly.** If you have a Terra array `var arr : int[5]`, you must explicitly pass a pointer to the first element, or cast the array pointer:
    *   *Wrong:* `C.takes_int_ptr(arr)` (This attempts a by-value copy of the entire array!)
    *   *Right:* `C.takes_int_ptr(&arr[0])`
    *   *Right:* `C.takes_int_ptr([&int](&arr))`
*   **Function Pointer Callbacks:** If a C function takes a callback (e.g., `qsort`), you can pass a Terra function directly. If you want to pass a *Lua* function as the callback, you must cast it first: `var cb = terralib.cast({&opaque, &opaque} -> int, my_lua_func)`. *Note: The Lua function must not throw errors that escape into the C caller, and the cast `cdata` object must not be garbage collected by Lua while C might still call it.*

### 18.6 The includecstring Pattern

Instead of reading a header from disk, `terralib.includecstring([[ ... C code ... ]])` compiles a raw string of C code.

This is an incredibly common idiom in Terra for working around the limitations of `includec`. If a C library relies heavily on macros, you can use `includecstring` to write a small C wrapper function directly inside your Lua script that invokes the macro, thus exposing it as a proper C function that Terra can call without needing external `.c` wrapper files.

### 18.7 Linking C Libraries

Importing a header via `includec` *only* imports the declarations (the types and function signatures). It does not link the actual executable code. If you try to call an imported function and get an "undefined symbol" error during JIT compilation, you must dynamically load the implementation.

The pattern is to pair `local C = terralib.includec("lib.h")` with `terralib.linklibrary("libname.so")`. For dynamic build environments, you can use Lua's `io.popen` to call `pkg-config --libs` and programmatically determine the correct paths to pass to `linklibrary`.

---

## 19. Compilation Model and Targets

### 19.1 JIT Compilation

By default, Terra functions are JIT-compiled by LLVM the first time they are executed. Once compiled, the resulting machine code pointer is cached; subsequent calls incur zero compilation overhead and jump directly to the native code.

You can force a function to compile beforehand by calling `myfunc:compile()`. Because Terra relies on a single LLVM execution engine instance, JIT compilation itself is not thread-safe. You must ensure that all required Terra functions are fully compiled (either by calling them or invoking `:compile()`) in the main thread before spawning OS threads that execute them.

### 19.2 AOT Compilation

For production environments, Terra is often used purely as an Ahead-Of-Time (AOT) compiler. The workflow involves writing a Lua script that generates and optimizes the Terra ASTs, and then calls `terralib.saveobj("out.o", { exported_name = myfunc })`.

This generates a standard native object file. You can then use your standard system linker (e.g., `gcc` or `clang`) to link `out.o` into your final application. The resulting binary contains pure machine code and has **zero dependencies** on Lua, Terra, or LLVM. It is exactly as if you had written the code in C.

### 19.3 LLVM IR

You can inspect the LLVM IR generated by Terra by passing `type = "llvmir"` to `saveobj`. This outputs a human-readable `.ll` file. This is invaluable for verifying that loops were vectorized, constants were folded, or specific intrinsic optimizations were applied.

You can also output LLVM bitcode (`type = "bitcode"`). This emits a `.bc` file. This is the standard entry point for using Terra with external LLVM tools like `opt` (for manual optimization passes) or compiling to WebAssembly (WASM) via the Emscripten toolchain (passing the `.bc` file directly to `emcc`).

Alternatively, for quick debugging in a script, you can print the entire LLVM module representing the current JIT compilation state by calling:
```lua
terralib.dumpmodule()
```

### 19.4 Cross Compilation

Terra supports cross-compilation using `terralib.newtarget({Triple = "target-triple"})`. You pass this target object to `saveobj`.

**Limitation:** While Terra will emit machine code for the target, `terralib.includec` still runs the Clang frontend on your *host* machine. If you include host headers (like `<stdio.h>`), Clang will parse the host's structs and ABI, which may mismatch the target (e.g., parsing 64-bit Linux headers while targeting 32-bit WASM). The practical pattern is to avoid standard headers during cross-compilation, explicitly define required C structs in Terra, and link against the target's libc later.

### 19.5 Optimization Levels

By default, Terra runs LLVM's standard `-O3` optimization pipeline before JIT executing or saving code.

When using `saveobj`, you can control this via the `optimize` parameter. Setting `optimize = false` disabled LLVM optimizations (equivalent to `-O0`). This is crucial for reducing compilation times during development or generating code suitable for stepping through with a debugger like GDB (though debug symbol support is limited). Terra's own meta-programming optimizations (like loop unrolling via Lua) happen before LLVM sees the code, so they apply regardless of the LLVM optimization level.

---

## 20. SIMD and Vector Programming

### 20.1 SIMD Via vector() Types

Terra's `vector(T, N)` type generates LLVM vector IR. Arithmetic (`+`, `-`, `*`, `/`) and bitwise operators applied to vectors generate pure SIMD instructions.

```terra
terra saxpy(a: float, X: vector(float, 4), Y: vector(float, 4))
    return a * X + Y
end
```

If the hardware does not support a specific vector width (e.g., `vector(float, 17)`), LLVM will automatically legalize the operation by breaking it into smaller supported vectors and scalar fallbacks. To ensure you are generating optimal SIMD, you should use native register widths (like 4 or 8 for floats) and use `:disas()` to visually confirm the presence of vectorized assembly instructions (like `vaddps`).

### 20.2 LLVM Intrinsics for SIMD

When standard vector arithmetic isn't enough, you can bind directly to platform-specific SIMD instructions using `terralib.intrinsic`. For instance, you can bind to `llvm.x86.avx.dp.ps.256` to access the AVX dot-product instruction.

The tradeoff is portability: code using x86 intrinsics will fail to compile on ARM. The standard pattern is to prefer Terra's generic `vector` types for basic math, and only fall back to platform-specific intrinsics (wrapped in Lua conditional logic checking `terralib.hosttarget.architecture`) for specialized operations like shuffles, blends, or complex reductions.

### 20.3 Data Layout for SIMD

SIMD requires loading contiguous chunks of identical data. The classic Array of Structs (AoS) pattern (e.g., `[xyz, xyz, xyz]`) defeats this because loading a vector of 'x' values requires non-contiguous memory accesses (strided loads or gathers), which are slow.

Using Lua metaprogramming, you can easily generate Struct of Arrays (SoA) layouts (e.g., `[xxx, yyy, zzz]`). You write a Lua function that takes an AoS struct definition and computationally generates an SoA equivalent. This guarantees that `vector` loads map directly to fast, contiguous hardware loads, maximizing cache utilization and SIMD throughput.

### 20.4 Auto-vectorization via LLVM

LLVM contains a powerful auto-vectorizer that can transform standard Terra scalar `for` loops into SIMD loops. For LLVM to do this safely, it must prove that memory accesses do not alias (overlap in a way that creates data dependencies), the loop has a predictable trip count, and control flow inside the loop is trivial.

Because Terra lacks a `restrict` keyword, LLVM often conservatively assumes pointers might alias and fails to auto-vectorize. To guarantee vectorization, it is almost always better in Terra to write explicit vector loops using `vector` types rather than relying on the auto-vectorizer.

---

## 21. Atomic Operations and Memory Ordering

### 21.1 The Atomic API

Terra exposes atomic operations through the `terralib.atomicrmw` (Read-Modify-Write) and `terralib.cmpxchg` (Compare-And-Exchange) APIs.

* `atomicrmw(op, ptr, val, {ordering="..."})`: Safely applies `op` (like `"add"`, `"xchg"`, `"fadd"`) to the memory at `ptr`. The `ptr` must point to an integer type (or floating-point for `fadd`/`fsub`). It returns the *old* value that was at the memory location before the operation.

    ```terra
    var i = 1
    terralib.atomicrmw("add", &i, 20, {ordering = "acq_rel"})
    -- i is now 21
    ```

* `cmpxchg(ptr, cmp, val, {success_ordering="...", failure_ordering="..."})`: Atomically compares the value at `ptr` with `cmp`. If they match, it writes `val`. It returns a tuple containing the old value and a boolean indicating success.

    ```terra
    var i = 1
    var old, success = terralib.cmpxchg(&i, 1, 4, {
        success_ordering = "acq_rel", 
        failure_ordering = "monotonic"
    })
    -- i is now 4, success is true
    ```

### 21.2 Memory Ordering Semantics

Every atomic operation requires an explicit memory ordering string mapped to LLVM's concurrency model:

* `"relaxed"`: No synchronization guarantees. Use for simple metrics or counters where order doesn't matter.
* `"acquire"` / `"release"` / `"acq_rel"`: Prevents instructions from being reordered past the atomic operation. The standard choice for implementing mutexes and spinlocks.
* `"seq_cst"` (Sequentially Consistent): The safest, strictest ordering, guaranteeing a global total order of operations. Use this by default unless you have proven a weaker ordering is safe, as `seq_cst` incurs a performance penalty by emitting strong hardware memory barriers.

### 21.3 Building Synchronization Primitives

Because Terra provides direct access to atomics, you can build custom, highly optimized synchronization primitives entirely in Terra without relying on OS-level pthreads.

A standard spinlock is implemented using `atomicrmw("xchg", ptr, 1, {ordering="acquire"})` in a `while` loop to acquire the lock, and `atomicrmw("xchg", ptr, 0, {ordering="release"})` to release it. You can similarly build lock-free concurrent queues or atomic reference counting pointers (smart pointers) using `cmpxchg` loops.

### 21.4 Integration with pthreads

Terra functions can be cast to `void* (*)(void*)` function pointers and passed directly to C's `pthread_create`.

**CRITICAL CONSTRAINT:** The LuaJIT runtime and the Terra compiler (LLVM) are *not* thread-safe. You cannot invoke macros, compile new Terra functions, or call back into Lua from within a thread spawned by `pthread`. The strictly enforced pattern is:

1. Generate and fully compile all required Terra functions in the main thread.
2. Spawn the pthreads, passing them the raw, compiled Terra function pointers.
3. The Terra code executes purely as native machine code, safely isolated from the Lua runtime.

---

## 22. Language Extensions: The Lexer/Parser Hook System

### 22.1 How the Extension System Works

Terra allows you to define custom syntax via its Lexer/Parser Hook System. A language extension is a Lua module that returns a table with the following fields:

* `name`: A string identifying the extension (for error reporting).
* `entrypoints`: A list of strings. When Terra's parser encounters one of these strings, it pauses standard parsing and hands control over to your extension's parsing function.
* `keywords`: A list of strings that become reserved tokens *only* while your extension is active.
* `expression` or `statement` or `localstatement`: One or more parsing functions that handle the custom syntax.

**Extension Scoping:** Language extensions are **block-scoped**. When you import an extension, its entrypoints are active only within the current lexical block (e.g., a function body or a `do ... end` block). When the block ends, the extension is automatically unimported and its entrypoints are no longer recognized.

### 22.2 The Lexer API

The `lex` object exposes methods to traverse the token stream:

**Token Navigation:**
* `lex:cur()`: Returns the current token without consuming it.
* `lex:next()`: Consumes and returns the current token, advancing to the next one.
* `lex:lookahead()`: Returns the next token without consuming it (looks ahead one token).

**Token Types (special singleton objects used with `expect`, `matches`, etc.):**
* `lex.name`: Matches `<name>` tokens (identifiers).
* `lex.string`: Matches string literal tokens.
* `lex.number`: Matches numeric literal tokens.
* `lex.eof`: Matches end-of-file.
* `lex.default`: Matches any token type.

**Token Consumption and Matching:**
* `lex:expect(tokentype)`: Consumes and returns the token if it matches, otherwise throws a formatted parse error.
* `lex:expectmatch(tokentype, openingtokentype, linenumber)`: Like `expect` but for matching bracket pairs (e.g., `lex:expectmatch('}', '{', line)`).
* `lex:matches(type_or_value)`: Returns true if the current token matches, without consuming it.
* `lex:lookaheadmatches(type_or_value)`: Returns true if the next token matches, without consuming it.
* `lex:nextif(type_or_value)`: Consumes and returns the token if it matches, otherwise returns `false`.

**Embedded Code Parsing:**
* `lex:terraexpr()`: Recursively calls Terra's parser to consume a valid Terra expression. Returns a constructor function that, when called with an environment function, returns the parsed Terra AST Quote.
* `lex:terrastats()`: Recursively parses a list of Terra statements. Returns a constructor function.
* `lex:luaexpr()`: Parses a Lua expression. Returns a constructor function.
* `lex:luastats()`: Parses Lua statements. Returns a constructor function.

**Variable Registration:**
* `lex:ref(name)`: Registers that your extension will access a Lua variable with the given name from the surrounding lexical environment.

**Error Handling:**
* `lex:error(msg)`: Throws a formatted syntax error anchored to the current token's source location.
* `lex:errorexpected(what)`: Throws an error indicating that `what` was expected.

### 22.3 Token Structure

Tokens returned by lexer methods are Lua tables with the following fields:

* `type`: The token type string (e.g., `"<number>"`, `"<name>"`, `"<string>"`, `"<eof>"`, or a specific keyword/operator like `"+"`, `"if"`, etc.).
* `value`: The actual value for names and strings (the identifier name or string content).
* `valuetype`: For number tokens, the Terra type object of the literal (e.g., `uint64`, `double`, `float`).
* `linenumber`: The source line number where the token appears.
* `offset`: The character offset in the source file.
* `filename`: The source filename.

Example of examining a number token:
```lua
local t = lex:expect(lex.number)
print(t.value)       -- the numeric value
print(t.valuetype)   -- Terra type object (e.g., uint64, double)
print(t.linenumber)  -- line number in source
```

### 22.4 Writing an Expression Extension

An expression extension is triggered inside a Terra expression (e.g., `var x = mydsl(...)`). Your extension table defines `expression = function(self, lex) ... end`.

The parsing function must:
1. Parse the custom syntax using the `lex` object
2. Return a **constructor function** that takes an environment function `env_fn` as its argument
3. The constructor returns the final value (a Lua value, Terra Quote, or AST) that will be spliced into the Terra code

The `env_fn` allows access to the surrounding lexical environment's variables. **CRITICAL:** If your DSL refers to Lua variables defined outside the DSL block, the parser *must* register those variable names using `lex:ref("varname")` during the parsing phase. If you fail to call `lex:ref()`, Terra's scope analyzer will garbage-collect or ignore the variable, and `env_fn()["varname"]` will be `nil` when the constructor runs!

Here is an example that sums a comma-separated list of numbers at compile time:

```lua
local sumlanguage = {
    name = "sumlanguage",
    entrypoints = {"sum"},
    keywords = {"done"},
    expression = function(self, lex)
        local total = 0
        lex:expect("sum")
        if not lex:matches("done") then
            repeat
                local t = lex:expect(lex.number)
                total = total + t.value
            until not lex:nextif(",")
        end
        lex:expect("done")
        -- Return constructor function that will be called during AST finalization
        return function(env_fn)
            return total -- can return a Lua value or a Quote
        end
    end
}
```

### 22.5 Writing a Statement Extension

A statement extension is triggered at the statement level (e.g., inside a function body or at the top level). Your extension table defines `statement = function(self, lex) ... end`.

Use an expression extension when your DSL produces a value. Use a statement extension when your DSL represents control flow, side effects, or declarations (like a custom `for` loop or a state machine transition).

**Statement extensions must return TWO values:**

1. **Constructor function**: A function that takes `env_fn` and returns the values to be assigned. For simple statements that don't produce values, return an empty list `{}`.
2. **Names list**: A list of variable names to assign the returned values to. Each name can be a string or a list of strings (for table access like `foo.bar`).

Example of a statement extension that defines a function:

```lua
return {
    name = "def",
    entrypoints = {"def"},
    statement = function(self, lex)
        lex:expect("def")
        local fname = lex:expect(lex.name).value
        lex:expect("(")
        local formal = lex:expect(lex.name).value
        lex:expect(")")
        local expfn = lex:luaexpr()
        -- Return constructor function and the variable name to assign
        return function(env_fn)
            return function(actual)
                local env = env_fn()
                env[formal] = actual
                return expfn(env)
            end
        end, { fname }
    end
}
```

You can use `lex:terrastats()` to parse block bodies within your custom statement, seamlessly mixing custom DSL logic with standard Terra code.

### 22.6 Registering Extensions

To use an extension, use the **`import`** keyword in your Terra code:

```terra
import "my_ext"  -- loads my_ext.lua and activates its entrypoints

terra example()
    var x = sum 1, 2, 3 done  -- using the extension's entrypoint
    return x
end
```

The `import` statement:
1. Uses Lua's `require()` to load the module
2. Automatically activates the extension's entrypoints for the current lexical block
3. Entrypoints become reserved keywords only within the scope of the import

**Extension files** must return a language definition table. Place your extension in a file like `my_ext.lua`:

```lua
-- my_ext.lua
return {
    name = "my_ext",
    entrypoints = {"sum"},
    keywords = {"done"},
    expression = function(self, lex)
        -- parsing logic here
    end
}
```

**Block Scoping:** Extensions are block-scoped. Entrypoints are only active within the block where `import` is called:

```terra
terra foo()
    import "my_ext"
    var x = sum 1, 2 done  -- works: entrypoint is active
    
    if true then
        var y = sum 3, 4 done  -- works: nested block inherits extensions
    end
end

terra bar()
    -- Entrypoints from "my_ext" are NOT active here
    -- var x = sum 1, 2 done  -- ERROR: "sum" not recognized
end
```

Multiple extensions compose gracefully as long as their `entrypoints` do not clash.

### 22.7 Recursive Extensions

For complex DSLs (like HTML templating or UI layouts), extensions often need to parse nested blocks of their own syntax. You achieve this by writing a recursive descent parser using the `lex` methods.

When your parser encounters a nesting construct, you call your own parsing function recursively until you hit a terminator token. To allow standard Terra expressions inside your DSL (e.g., for dynamic attributes), interleave calls to `lex:terraexpr()`. The result is typically a nested Lua table (an AST) representing the DSL, which your constructor function then transforms into a deeply nested Terra Quote when called with the environment.

### 22.8 Extension Error Handling

When writing parsers, you must handle invalid syntax gracefully. The `lex` object tracks source locations.

If you use `lex:expect("}")`, it automatically throws a formatted error (e.g., `Expected '}' but found EOF at line 42`) if the token is missing. For custom semantic errors, you should use `lex:error("Custom error message")` rather than Lua's standard `error()`. This ensures the error stack trace points to the precise line and column in the user's `.t` file where the DSL syntax failed, rather than pointing to the internal Lua code of your parser.

---

## 23. Building DSLs

### 23.1 The Philosophy: Notation Over API

DSLs prioritize notation over API. In standard libraries, complex behaviors (like SQL queries, regex, or hardware pipelines) are often expressed via awkward chained method calls or verbose configuration objects. A DSL allows the programmer to write code using the domain's natural notation (e.g., actual SQL syntax or matrix math notation).

Terra's deep module philosophy argues that libraries shouldn't just provide functions; they should provide the language constructs necessary to use those functions optimally. DSLs are worth the investment when the domain logic is highly constrained but requires aggressive, domain-specific optimization (like fusing stencil loops). They are not worth it for simple CRUD operations where standard Terra functions suffice.

### 23.2 Parsing Strategies

When building a DSL, you have two primary parsing strategies. For simple, linear syntaxes (like `from table select x`), you can manually traverse tokens using `lex:next()` and `lex:matches()`.

For mathematically rich DSLs, you often need to handle operator precedence (e.g., `a + b * c`). Writing a recursive descent parser for precedence is tedious. A common Terra idiom is to use a Pratt Parser (Top-Down Operator Precedence) implemented in Lua. You register prefix and infix parsing functions for your DSL tokens. When you want to allow users to inject standard Terra code into your DSL (like `where [terra_expr]`), you delegate by calling `lex:terraexpr()` and splicing the resulting quote into your AST.

### 23.3 Building ASTs from the DSL

The standard compilation pipeline for a Terra DSL is:

1. **Parse:** The lexer hook transforms the token stream into a custom Lua AST.
2. **Analyze/Transform:** You write pure Lua functions to traverse this AST, performing domain-specific optimizations (like dead code elimination or loop fusion).
3. **Generate:** You write a recursive Lua function `codegen(node)` that matches on the node type and returns a Terra Quote. The final Quote is spliced into the user's Terra code.

### 23.4 Abstract Syntax Description Language (ASDL)

Instead of building ad-hoc Lua tables for your AST, Terra bundles a powerful ASDL library (`require("asdl")`) specifically for building compiler Intermediate Representations (IR). ASDL allows you to define typed algebraic data types (variants/enums) succinctly.

```lua
local asdl = require("asdl")
local IR = asdl.NewContext()

IR:Define [[
    -- A tagged union (variant)
    Expr = BinOp(Expr lhs, string op, Expr rhs)
         | Number(number val)
         | Var(string name)
         
    -- A list is denoted by '*'
    Stmt = Block(Stmt* statements)
         | Assign(string name, Expr val)
]]

-- Instantiating an AST node:
local my_ast = IR.BinOp(IR.Number(5), "+", IR.Number(10))

-- Checking node types during codegen:
if IR.BinOp:isclassof(node) then
    local lhs_quote = codegen(node.lhs)
    local rhs_quote = codegen(node.rhs)
    return quote operator(node.op, [lhs_quote], [rhs_quote]) end
end
```

ASDL enforces strict construction types and automatically provides `.kind` properties (e.g., `node.kind == "BinOp"`). It is highly recommended for any non-trivial Terra DSL.

### 23.5 Type Checking in DSLs

Because Terra macros and compiler hooks receive Quotes representing AST nodes, you can perform domain-specific type checking before generating the final code.

You can query `quote_node:gettype()` to verify that an injected Terra expression matches the DSL's requirements (e.g., ensuring the `where` clause expression evaluates to a `bool`). If the types do not match, you can throw a Lua `error()` or use `lex:error()` if inside the parsing phase. Because this validation happens entirely in Lua during the compilation phase, invalid DSL code is caught strictly at compile-time with zero runtime cost.

### 23.6 The thing(params) children end Pattern

The `thing(params) children end` pattern is ubiquitous for hierarchical DSLs like state machines or UI layouts.

The parser encounters the `thing` token, parses its parameters (often using `lex:terraexpr()`), and then enters a `while not lex:matches("end")` loop to recursively parse children. The resulting AST is a tree of Lua tables: `{ kind = "state", name = "Idle", children = { ... } }`. The `codegen` phase recursively transforms this tree into Terra code. For a state machine, the generator might emit a `struct` representing the machine, an `enum` for the states, and a large `if/elseif` or `goto` block representing the transitions based on the parsed children.

### 23.7 DSL Examples

Terra has been used to build numerous sophisticated DSLs:

* **Stencil Compilers (Orion):** A DSL for image processing where high-level operations are analyzed in Lua, buffered, and compiled down to heavily vectorized LLVM IR.

    ```lua
    -- Orion DSL allows high-level math notation:
    function diffuse(x, x0, diff, dt)
        local a = dt * diff * N * N
        for k = 0, iter do
            x = (x0 + a*(x(-1,0) + x(1,0) + x(0,-1) + x(0,1))) / (1+4*a)
        end
        return x, x0
    end
    ```

    This cleanly replaces deeply nested C loops and manual array indexing (`x[IX(i-1,j)]`), while the Terra-based compiler backend fuses the loops and emits vector instructions.
* **State Machines:** A DSL that parses `state A { on Event goto B }` and generates an optimized C-compatible state machine using `goto` statements.
* **Probabilistic Programming:** DSLs that compile high-level statistical models directly into high-performance Markov Chain Monte Carlo (MCMC) samplers, achieving orders of magnitude speedups over purely interpreted implementations.

---

## 24. High-Performance Patterns via Metaprogramming

### 24.1 Specialization Over Generics

The most powerful metaprogramming pattern in Terra is type specialization. Instead of rigid generics, you write a Lua function `MakeList(T)` that dynamically constructs and returns a unique `struct ListT { data: &T }`.

This is vastly superior to C++ templates. C++ templates rely on pattern matching and SFINAE, leading to exponential compilation times and horrific error messages. Terra's approach uses standard, imperative Lua logic to assemble the type. Because this logic executes during Phase 1 (Lua Execution), by the time Terra compiles the function, it sees a simple, monomorphic struct. This guarantees zero runtime cost while keeping compilation blisteringly fast.

### 24.2 Compile-Time Loop Unrolling and Blocking

Instead of relying on LLVM's unpredictable heuristic auto-unroller, you can explicitly unroll critical loops at compile-time using Lua:

```lua
local unrolled_body = terralib.newlist()
for i = 0, UNROLL_FACTOR - 1 do
    unrolled_body:insert(quote data[base + [i]] = 0 end)
end
terra clear(data: &int, base: int) [unrolled_body] end
```

This explicitly generates repeated assignments in the AST. Unrolling reduces branch overhead and exposes instruction-level parallelism.

Similarly, multi-level cache blocking (tiling) can be generated recursively via Lua:

```lua
function blockedloop(N, blocksizes, bodyfn)
    local function generatelevel(n, ii, jj, bb)
        if n > #blocksizes then return bodyfn(ii, jj) end
        local blocksize = blocksizes[n]
        return quote
            for i = ii, min(ii+bb, N), blocksize do
                for j = jj, min(jj+bb, N), blocksize do
                    [ generatelevel(n+1, i, j, blocksize) ]
                end
            end
        end
    end
    return generatelevel(1, 0, 0, N)
end
```

By making the block sizes Lua parameters, an auto-tuner can test multiple configurations and dynamically select the optimal sizes for the target hardware's L1/L2 caches.

### 24.3 Baking Constants into Code

When a Lua value is escaped into Terra (e.g., `return [ 5 * 2 ]`), it becomes a literal in the LLVM IR. This is significantly faster than loading a constant from memory because it saves a load instruction and relieves L1 cache pressure.

More importantly, baking constants enables extreme LLVM constant folding. If you bake in the stride of a matrix or the length of an array, LLVM can compute loop bounds statically, eliminate dead branches, and optimize pointer arithmetic into single LEA (Load Effective Address) instructions. This is heavily used in high-performance libraries like BLAS auto-tuners.

### 24.4 Struct Layout Optimization via Metaprogramming

Because `struct.entries` can be populated algorithmically in Lua, you can dynamically optimize struct layouts based on target architecture or data.

For example, a Lua generator can automatically sort fields by size (largest to smallest) to minimize struct padding. More advanced implementations can group "hot" fields (frequently accessed together) into the first 64 bytes to guarantee they fit within a single CPU cache line, while pushing "cold" fields (rarely accessed, like debug names) to the end. You can also generate completely different internal layouts (like Array-of-Structs vs. Struct-of-Arrays) while presenting the identical programmatic interface to the user.

### 24.5 Generic Algorithms

Generic algorithms are implemented as Lua factories that return specialized Terra functions.

A prime example is auto-generating serialization routines by introspecting struct fields:

```lua
local createwrite = terralib.memoize(function(T)
    if T:isstruct() then
        local function emitPointers(self, obj)
            local stmts = terralib.newlist()
            for _, e in ipairs(T:getentries()) do
                if e.type:ispointer() then
                    local fn = createwrite(e.type.type)
                    stmts:insert(quote fn(self, obj.[e.field]) end)
                elseif e.type:isstruct() then
                    -- recursively emit fields
                end
            end
            return stmts
        end
        return terra(self : &Serializer, obj : &T)
            self:writebytes([&uint8](obj), sizeof(T))
            [emitPointers(self, obj)]
        end
    end
end)
```

This pattern generates a bespoke serialization routine strictly optimized for `T`. The generated function copies the flat parts of the struct in a single contiguous block via vectorization (fusion optimization), and explicitly generates subsequent pointer writes inline. This eliminates any dynamic reflection overhead at runtime, running up to 11x faster than Java's Kryo.

### 24.6 JIT Specialization at Runtime

Terra's ultra-fast LLVM JIT compilation makes runtime specialization practical. A host application can invoke Terra, pass in runtime data (like a database query string or a shader AST), and Terra will instantly compile a highly specialized machine code routine to execute that exact query.

By baking the exact query structure, filter constants, and data types into the generated code, you eliminate all dynamic interpretation overhead. The generated code executes as a tight, unrolled loop operating directly on memory. This is the exact architecture used by modern high-performance SQL engines (like PostgreSQL's JIT) and graphics drivers.

### 24.7 Profile-Guided Specialization

Because Terra runs inside Lua, you can easily implement Profile-Guided Optimization (PGO) dynamically.

The pattern involves initially compiling a generic Terra function that includes profiling counters (e.g., tracking the most common runtime types passed to an interface). The Lua orchestrator monitors these counters. Once a "hot" path is identified, Lua dynamically generates and compiles a new Terra function *specifically optimized* for that hot path (e.g., removing branches by asserting the known type). The execution is then hot-swapped to the new function. This adaptive specialization is a hallmark of tracing JITs (like LuaJIT itself), but Terra puts this power directly in the hands of the library developer.

---

## 25. Error Handling Patterns

### 25.1 Error Handling Philosophy in Terra

Terra does not support C++-style exceptions (`try`/`catch`) or implicit error propagation. This explicit design choice ensures that control flow remains completely visible and predictable, a critical requirement for low-level systems programming where hidden stack unwinding can lead to memory leaks or broken state.

All errors must be handled explicitly through return values or program termination. The three available approaches are returning C-style integer error codes, returning multiple values (result and error), or building a custom `Result` type via metaprogramming.

### 25.2 Error Codes

The most basic approach, inherited from C, is returning integer error codes (e.g., `0` for success, `< 0` for errors). For functions that must return a computed value, Terra's native multiple return values provide a cleaner idiom:

```terra
terra read_file(path: &int8) : {&int8, int}
    -- returns {buffer, 0} on success, {nil, err_code} on failure
end
```

While cleaner than passing pointers for output arguments, this pattern relies purely on programmer discipline to check the second return value before using the first.

### 25.3 Result Types via Metaprogramming

For robust applications, you can use Lua to generate a generic `Result(T, E)` tagged union (a struct containing a boolean `is_ok`, the value `T`, and the error `E`).

By leveraging the `__methodmissing` metamethod or macros, you can even implement Rust-like error propagation (similar to the `?` operator). A macro `unwrap_or_return(res)` can evaluate the result, extract `T` if successful, or immediately emit a `return res.error` if it failed. This provides immense safety but requires upfront investment in the DSL infrastructure.

### 25.4 Panic and Assertions

For unrecoverable states (e.g., corrupted memory, bounds violations), the standard approach is to log an error and call `C.abort()`.

Because Terra is meta-programmed, assertions should be implemented as Lua macros. A `MacroAssert(condition, msg)` macro checks a global Lua variable like `BUILD_TYPE`. If `BUILD_TYPE == "release"`, the macro returns an empty quote `{}`, completely stripping the assertion from the generated machine code. This allows you to pepper your code with aggressive invariants that cost absolutely nothing in production.

### 25.5 Setjmp/Longjmp Interop

Terra can interoperate with C libraries that use `setjmp` and `longjmp` for error handling (like `libjpeg` or `libpng`).

However, **this is extremely dangerous if Terra code is on the stack between the `setjmp` and the `longjmp`.** Because `longjmp` brutally unwinds the stack without executing cleanup code, any Terra `defer` statements or manual `C.free()` calls waiting on that stack frame will be bypassed, resulting in immediate memory leaks or deadlocks. You must isolate `setjmp` boundaries purely within C code or carefully at the very top of your Terra call stack.

---

## 26. Debugging and Introspection

### 26.1 printpretty: Reading Terra ASTs

The `myfunc:printpretty()` method prints a textual, LISP-like representation of the fully resolved Terra Abstract Syntax Tree.

This is the most critical tool for debugging metaprogramming. It shows you the exact code *after* all macros have been expanded, all escapes have been spliced, and all types have been inferred. If you generated a loop dynamically, `printpretty` will show you the exact variables, types, and operations that were emitted. It helps verify hygiene (ensuring generated variable names don't clash) and confirms that your Lua generator logic produced the intended structure.

### 26.2 disas: Reading Generated Assembly

The `myfunc:disas()` method prints the LLVM IR and the final, optimized machine code (e.g., x86 or ARM assembly) generated by the compiler.

Use this to verify performance claims: check that complex math folded into single constants (verifying `[constant]` escapes), check that function calls disappeared (verifying inlining), and check for the presence of vectorized instructions (like `vaddps` instead of `addss`) to confirm SIMD execution. Reading the assembly is the ultimate source of truth for understanding exactly what the CPU will execute.

### 26.3 terralib.printversion()

The `terralib.printversion()` function outputs diagnostic information about the current Terra environment. It details the specific version of Terra, the underlying LLVM version it was compiled against, and the architecture it is targeting. This is useful for identifying compatibility issues when using platform-specific LLVM intrinsics.

### 26.4 Runtime Debugging

For runtime debugging, the simplest approach is `C.printf` imported via `includec`.

Because Terra generates pure native code, you can attach standard native debuggers like `gdb` or `lldb` to the process. Terra attempts to embed DWARF debug information (sourcemaps) into the LLVM IR, mapping the machine code back to the line numbers in your `.t` source files. This allows you to set breakpoints, step through Terra code, and inspect Terra variables exactly as you would with a C program.

### 26.5 Type and Quote Inspection

During compilation (inside macros or generators), you use `node:gettype()` on Quote objects to determine what type of expression was passed in. You can also inspect the internal structure of the AST node itself (e.g., checking if `node.tree.kind == "literal"`).

If you have a boxed `cdata` object in Lua representing a Terra value, `terralib.typeof(obj)` returns its Terra type object. This introspection allows your Lua metaprograms to gracefully adapt, generating different Terra code pathways based on whether the user provided a float, an integer, or a custom struct.

---

## 27. Complete API Reference

> This section is a comprehensive, structured reference for every function and
> value in the terralib namespace. It supplements rather than replaces the
> preceding sections.

### 27.1 terralib Functions (alphabetical)

**`terralib.attrload(addr, attrs)`**: Performs a load with attributes (`nontemporal`, `align`, `isvolatile`).
**`terralib.attrstore(addr, value, attrs)`**: Performs a store with attributes.
**`terralib.atomicrmw(op, ptr, val, options)`**: Emits an atomic read-modify-write LLVM instruction.
**`terralib.cast(Type, value)`**: Performs a raw Terra cast on a value, returning a Quote.
**`terralib.cmpxchg(ptr, cmp, val, options)`**: Emits an atomic compare-and-exchange LLVM instruction.
**`terralib.constant(type, value)`**: Creates an LLVM global constant.
**`terralib.externfunction(name, type)`**: Creates a Terra function bound to an external symbol.
**`terralib.fence(attrs)`**: Issues a memory fence/barrier operation.
**`terralib.global(type, [init_val])`**: Creates a mutable global variable.
**`terralib.includec(header_path, [args...])`**: Invokes Clang to parse a C header and returns a Lua table of bindings.
**`terralib.includecstring(c_code, [args...])`**: Compiles inline C code and returns bindings.
**`terralib.intrinsic(name, type)`**: Returns a Terra function representing an LLVM built-in intrinsic.
**`terralib.isconstant(c)`**: Returns true if `c` is a Terra constant.
**`terralib.isfunction(f)`**: Returns true if `f` is a Terra function.
**`terralib.islabel(l)`**: Returns true if `l` is a Terra label.
**`terralib.islist(l)`**: Returns true if `l` is a Terra List.
**`terralib.ismacro(m)`**: Returns true if `m` is a Terra macro.
**`terralib.isoverloadedfunction(f)`**: Returns true if `f` is an overloaded Terra function.
**`terralib.istype(t)`**: Returns true if `t` is a Terra type.
**`terralib.label([displayname])`**: Creates a new unique label for use with `goto`.
**`terralib.linklibrary(path)`**: Dynamically loads a shared library into the JIT environment.
**`terralib.linkllvm(filename)`**: Links an LLVM bitcode file (`.bc`) for inlining across modules.
**`terralib.loadfile(path, [env])`**: Compiles a `.t` file into a Lua chunk function.
**`terralib.loadstring(code, [name, env])`**: Compiles a string into a Lua chunk function.
**`terralib.memoize(fn)`**: Wraps a function to cache results based on arguments.
**`terralib.new(terratype, [init])`**: Allocates a new Terra object (wrapper around `ffi.new`).
**`terralib.newtarget(options)`**: Instantiates an explicit compilation target for cross-compiling.
**`terralib.offsetof(Type, field_name)`**: Returns the byte offset of a field within a struct.
**`terralib.overloadedfunction(name, funcs)`**: Creates a statically dispatched overloaded function.
**`terralib.printversion()`**: Prints Terra version, LLVM version, and target info.
**`terralib.saveobj(path, exports, options)`**: Compiles Terra functions to native disk formats (.o, .so, executable).
**`terralib.select(cond, val1, val2)`**: Built-in macro for conditional selection.
**`terralib.sizeof(Type)`**: Returns the size in bytes of a Terra type.
**`terralib.typeof(obj)`**: Returns the Terra type object of a cdata instance.

### 27.2 Terra Type Methods

All Terra Type objects expose boolean predicates to identify their category: `:isprimitive()`, `:ispointer()`, `:isarray()`, `:isvector()`, `:isstruct()`, `:isfunction()`, `:isintegral()`, `:isfloat()`, `:isarithmetic()`, `:islogical()`, `:canbeord()`, `:isaggregate()`, `:iscomplete()`, `:ispointertostruct()`, `:ispointertofunction()`, `:isunit()`, and type-or-vector variants (`:isprimitiveorvector()`, etc.).

Additional type methods:
* `type:complete()` - Forces the type to be fully defined (calculates struct layout).
* `type:printpretty()` - Prints the type including its members if a struct.

Depending on the type, specific properties are populated:

* **Pointer Types**: `T.type` points to the underlying pointed-to type.
* **Array Types**: `T.type` is the element type, and `T.N` is the integer length.
* **Vector Types**: `T.type` is the scalar element type, and `T.N` is the SIMD width.
* **Function Types**: `T.parameters` is a list of argument types, and `T.returntype` is the return type.

### 27.3 Terra Function Methods

Terra function objects (tables representing uncompiled or compiled ASTs) expose:

* `fn:compile()`: Forces JIT compilation.
* `fn:disas()`: Prints LLVM IR and native assembly.
* `fn:printpretty()`: Prints the typed Terra AST.
* `fn:printstats()`: Prints statistics about compilation and JIT time.
* `fn:gettype()`: Returns the `{Args...} -> {Returns...}` function type.
* `fn:getpointer()`: Forces compilation and returns a raw `cdata` function pointer.
* `fn:getname()` / `fn:setname(str)`: Get/set the pretty name for debugging.
* `fn:setinlined(bool)`: Adds or removes the LLVM always-inline attribute.
* `fn:setoptimized(bool)`: Enables/disables LLVM optimization (-O3 vs -O0).
* `fn:setcallingconv(str)`: Sets the calling convention (e.g., "fastcc", "coldcc").
* `fn:isdefined()`: Returns true if the function has a definition.
* `fn:isextern()`: Returns true if bound to an external symbol.
* `fn:adddefinition(other_fn)`: Sets definition from another function (must be undefined).
* `fn:resetdefinition(other_fn)`: Resets definition from another function (can be defined).
* `fn:getdefinitions()`: (Only for overloaded functions) Returns the list of underlying Terra functions.

### 27.4 Terra Struct Methods

Struct objects contain several mutable tables used for metaprogramming:

* `Struct.entries`: A Lua list of tables `{field="name", type=T}` defining the memory layout.
* `Struct.methods`: A Lua table mapping strings to Terra functions.
* `Struct.metamethods`: A Lua table containing Exotype compiler hooks (`__cast`, `__methodmissing`, etc.).
Additionally, `Struct:getmethod(name)` retrieves a method (handling inheritance/metamethods if applicable), and `Struct:complete()` explicitly finalizes the struct layout, preventing further additions to `entries`.

### 27.5 Quote Methods

Quote objects (AST nodes passed to macros or escapes) expose:

* `quote:gettype()`: Returns the inferred Terra type of the AST node.
* `quote:astype()`: Tries to interpret the quote as a Terra type (used in macros expecting type arguments).
* `quote:asvalue()`: If the node represents a compile-time constant literal, this returns the actual Lua value (e.g., the number `5`). If not constant, it throws an error.
* `quote:islvalue()`: Returns true if the expression represents a memory location that can be assigned to (e.g., a variable or array index), false if it is a transient rvalue.
* `quote.tree`: Direct access to the internal Lua table representing the raw AST structure.
* `quote.tree:is("literal")`: Checks if the internal AST node is of a specific kind (e.g. `"literal"`, `"operator"`, `"var"`, `"apply"`, `"index"`).

### 27.6 Lexer API (for language extensions)

The Lexer object passed to language extensions provides:

* `lex:next()`: Consumes 1 token, returns `{type, value, linenumber, offset}`.
* `lex:lookahead()`: Returns the next token without consuming.
* `lex:expect(tok)`: Consumes 1 token if it matches `tok`, else errors.
* `lex:matches(tok)`: Returns boolean indicating if next token matches `tok`.
* `lex:nextif(tok)`: Consumes and returns 1 token if it matches `tok`, else returns nil.
* `lex:terraexpr()`: Hands control to Terra parser, returns an Expression Quote.
* `lex:terrastats()`: Hands control to Terra parser, returns a Statement List Quote.
* `lex:error(msg)`: Throws a syntax error anchored to the current line number.

---

## 28. Known Quirks and Sharp Edges

> This section documents behaviors that are correct but surprising.
> Read it before you spend hours debugging.

### 28.1 Lua Is Not Thread Safe

The most critical architectural constraint in Terra is that **the Lua runtime (and by extension, the Terra JIT compiler) is strictly single-threaded.**

If you spawn OS threads (e.g., using `pthread`), those threads *cannot* invoke Terra macros, cannot trigger JIT compilation of uncompiled functions, and cannot call back into Lua. The standard design pattern to overcome this is strict phasing: you must JIT compile all necessary Terra code in the main thread, extract the raw `cdata` function pointers via `:getpointer()`, and pass those pure native pointers to your worker threads.

### 28.2 No Calling Lua from Terra at Runtime

A common mistake is trying to write `[ print("hello") ]` inside a Terra loop, expecting it to print repeatedly at runtime. This fails because escapes `[]` evaluate at *compile-time*.

Terra code compiles to pure LLVM machine code; it has no inherent connection to the Lua Garbage Collector or Lua Stack. To invoke Lua from running Terra code, you must manually bridge the gap using LuaJIT's FFI. You must cast a Lua function to a C function pointer (`terralib.cast({int}->{}, my_lua_func)`) and invoke the pointer. This incurs a context-switch penalty but allows controlled callbacks.

### 28.3 Terra Struct Copy Semantics

Unlike classes in Java or tables in Lua, **Terra structs are value types.** If you assign a struct to a new variable or pass it to a function, Terra performs a shallow, byte-for-byte copy of the entire memory block.

This is a massive performance hazard for large structs. Furthermore, it introduces subtle bugs: if you pass a struct by value to an initialization function, that function modifies its *local copy*, leaving the original struct untouched. The correct, pervasive idiom is to almost always pass and return structs by pointer (`&MyStruct`).

### 28.4 The & Ambiguity

The `&` character is heavily overloaded. In type annotations (`var x : &int`), it is the pointer type constructor. In expressions (`var x = &y`), it is the address-of operator.

Ambiguity arises when passing arguments to macros or escapes. Is `&T` evaluating to a pointer type, or trying to take the address of a variable named `T`? Terra uses the syntactic context to deduce intent, but when writing complex Lua meta-programs that generate quotes dynamically, you must be extremely precise. If Terra misinterprets an expression, explicitly wrapping it in `terralib.types.pointer(T)` inside an escape clarifies the intent.

### 28.5 Uninitialized Variables

Declaring `var x : int` allocates stack space but **does not initialize the memory**. `x` will contain arbitrary garbage data left over from previous stack frames.

This is intentional: zero-initializing every variable incurs a measurable performance cost in tight loops. The programmer must maintain strict discipline to initialize variables before reading them. A common debugging pattern is to temporarily alter your struct constructors or variable declarations to explicitly initialize memory to a known poison value (like `0xDEADBEEF`) to rapidly flush out uninitialized read bugs.

### 28.6 Destructors and Function Arguments

If you implement an explicit destructor mechanism (e.g., via macros or `defer`), passing a struct by value is extremely dangerous.

When you pass by value, the struct is shallow-copied. When the callee function exits, the copy goes out of scope and the destructor fires, freeing the internal pointers. However, the caller's original struct still holds those same pointers, which are now dangling. A subsequent access or double-free will crash the program. The absolute rule when implementing RAII in Terra is: **types managing heap resources must strictly forbid by-value copying**, either through compiler enforcement via macros or strict developer discipline to pass by pointer.

### 28.7 Escape Evaluation Order

Escapes `[ ]` are evaluated during the initial Lua parsing phase, exactly when the `terra` keyword block is constructed. They are *not* evaluated when the Terra function is called.

If you write `terra foo() return [ global_counter ] end`, and then later increment `global_counter` in Lua, `foo()` will permanently return the old value. The value was permanently baked into the AST. If you need a value to dynamically track mutable Lua state at runtime, you must pass it as an argument to the Terra function, or read it through an FFI pointer.

### 28.8 includec and Host Headers

The `terralib.includec` function invokes Clang on the *host* machine executing the script. It uses the host's `/usr/include` paths and the host's struct alignments.

This makes cross-compilation treacherous. If you compile on macOS targeting Windows, `includec("stdio.h")` will parse the macOS headers, embedding macOS-specific offsets into your Terra AST. When you run that code on Windows, it will segfault. To write portable cross-compiled Terra, you must either avoid `includec` entirely (manually defining the required C structs and function signatures in Terra) or carefully manage sysroot paths passed to Clang.

### 28.9 Macro Arguments Are Untyped Until Analyzed

A classic beginner mistake is writing a macro like `macro(function(x) if x == 5 then ... end)`. This fails silently or bizarrely because `x` is not the number `5`; it is a Lua table representing the AST Node for a literal `5`.

You cannot evaluate the logic of the node natively in Lua unless you use `x:asvalue()` (which only works for constants). For runtime variables, the macro must inspect `x:gettype()` and emit a Terra Quote containing the actual runtime `if` statement: `return quote if x == 5 then ... end end`.

### 28.10 The LuaJIT 2GB Limit

Due to its highly optimized garbage collector and pointer tagging, LuaJIT historically limits its own GC-managed heap to 1GB or 2GB of virtual address space on 64-bit platforms (though newer LuaJIT versions are relaxing this).

If you allocate massive arrays using Lua tables, you will OOM and crash. The standard Terra pattern is to bypass the Lua GC entirely for bulk data: allocate massive arrays using `C.malloc` in Terra, cast them to the correct pointer type, and pass the pointer back to Lua as a `cdata` object. The Lua GC only tracks the tiny pointer, while the gigabytes of memory reside safely in the unmanaged C heap.

---

## 29. Patterns and Idioms

### 29.1 The Generic Type Pattern

```lua
local function Vec(T)
  local struct VecT { ... }
  terra VecT:method() ... end
  return VecT
end
local Vec3f = Vec(float)
local Vec3d = Vec(double)
```

This is the foundational pattern for generics in Terra, directly replacing C++ templates. You write a standard Lua function (`Vec(T)`) that receives a Terra type object `T`. Inside the function, you locally define a new `struct` and its associated methods, dynamically injecting `T` via closures. Finally, you return the fully constructed struct type.

Variations of this pattern include accepting integer parameters for fixed-size collections (e.g., `Vec(T, N)`), passing function callbacks for generic algorithms (e.g., `Map(T, transformation_quote_generator)`), or inspecting `T` with `T:ispointer()` to conditionally generate entirely different internal memory layouts based on the input type.

### 29.2 The Cached Specialization Pattern

```lua
local cache = {}
local function get_vec(T)
  if not cache[T] then cache[T] = make_vec(T) end
  return cache[T]
end
```

When generating complex generic types, evaluating the Lua logic and instantiating the methods takes a small but measurable amount of time. If you call `get_vec(float)` thousands of times inside a loop, regenerating the struct each time will needlessly bloat the compiler's memory and increase compile times.

Caching guarantees that `get_vec(float) == get_vec(float)`. This is critical for type safety: Terra uses structural identity for nominal types, meaning two independently generated structs with identical fields are considered *different types*. You must cache generated types if instances of those types need to interact with each other (e.g., passing a `Vec` generated in module A to a function in module B).

### 29.3 The Compile-Time Dispatch Pattern

Compile-time dispatch moves conditional logic from the runtime CPU out to the Lua meta-program.

If you have a generic math function, you don't write a Terra `if` statement checking the type. Instead, you write a Lua `if` statement inside the generator: `if T:isfloat() then return quote ... float_logic ... end else return quote ... int_logic ... end`. When the Terra function is compiled, only the correctly matched branch is spliced into the AST. The generated machine code contains zero branching overhead, perfectly specializing the logic for the precise hardware data type.

### 29.4 The Arena Allocator Pattern

An Arena (or Bump) Allocator is a massive, contiguous block of memory allocated once via `C.malloc`. An internal pointer tracks the current "head" of the allocated space.

Allocating a new struct simply involves casting the head pointer to the struct type and advancing the head by `sizeof(Struct)`. Freeing individual objects is impossible; instead, you "reset" the arena by simply moving the head pointer back to zero. Arenas perfectly match Terra's manual memory model because they bypass the need for complex, per-object destructors (`__destruct`). You can allocate millions of AST nodes or graph edges, and discard them instantly at the end of a frame or compilation pass.

### 29.5 The Builder Pattern

Instead of writing massive, monolithic Lua functions to generate code, the Builder pattern utilizes stateful Lua tables. You create an object like `local builder = QueryBuilder:new()`. You progressively call methods on it (`builder:add_filter(expr)`, `builder:set_limit(10)`), which internally accumulate Terra Quotes in Lua lists.

Finally, you call `builder:compile()`, which iterates over the accumulated Quotes, splices them into a final Terra function AST, and returns the compiled function. This is heavily used when constructing complex DSLs where the AST must be analyzed, optimized, and rearranged before final code emission.

### 29.6 The Vtable Pattern

Terra relies entirely on static dispatch by default. To achieve runtime polymorphism (interfaces/virtual methods), you manually construct a Virtual Method Table (vtable).

Using Lua metaprogramming, you can define an interface generator that automatically creates a struct containing function pointers, similar to C++ vtables, but with complete control over the layout.

```lua
-- Conceptual Vtable pattern
local function MakeInterface(InterfaceName)
    local struct VTable {
        do_work : {&opaque} -> int
    }
    local struct Interface {
        instance : &opaque,
        vtable : &VTable
    }
    
    terra Interface:do_work()
        return self.vtable.do_work(self.instance)
    end
    
    return Interface
end
```

The generator takes a concrete struct, creates a global constant instance of that vtable populated with the concrete methods, and injects a pointer to that vtable into the concrete struct (or a fat pointer `Interface` wrapper). Because you control the exact memory layout of the vtable and the calling conventions, you can heavily optimize dispatch.

### 29.7 The Module Pattern

A Terra module is simply a Lua file that returns a table. This table acts as the public namespace for your library.

You populate the table with the exported Terra types, compiled Terra functions, and the Lua meta-programming APIs (like macros or generic type generators) required to interact with them. When a user calls `local my_lib = require("my_lib")`, they receive this unified interface. By keeping internal C imports and helper functions as `local` variables in the Lua file, you achieve robust encapsulation, shielding the user from the low-level implementation details of the library.

### 29.8 The Fibers Pattern

Terra can implement high-performance, cooperative user-space threads (Fibers or Coroutines) using OS primitives like POSIX `ucontext` or custom assembly context switches.

You build a global Scheduler struct in Terra that maintains a queue of ready fibers. A custom language extension introduces a `go` keyword (`go my_func()`), which allocates a new stack, sets up the `ucontext`, and enqueues the fiber. Yielding simply swaps the CPU registers. By coupling this with type-safe Channels (generated via the Generic Type Pattern), you can build highly concurrent, Go-style actor models that execute entirely in user-space with nanosecond context-switch overheads.

---

## 30. The GIS Case Study: Everything Together

> This section demonstrates every major concept from this document applied to
> a realistic production library: a high-performance spatial data processing
> library with multi-language bindings.

### 30.1 Architecture Overview

This case study examines a high-performance GIS (Geographic Information System) library. The architecture is cleanly bifurcated: Lua orchestrates the compilation, defines the DSL parsers, and manages the type definitions (e.g., distinct coordinate systems). Terra executes the raw number crunching, bounding-box checks, and memory management.

The user interacts with the library entirely through a Lua API and a custom query DSL. The binding generation strategy uses Lua to introspect the generated Terra structs and functions, automatically emitting C headers and Python `ctypes` wrappers, allowing the library to be seamlessly consumed by external Data Science ecosystems.

### 30.2 Geometry Types with CRS Phantom Types

A common GIS error is calculating the distance between a Lat/Lon point (WGS84) and a projected point (WebMercator). To prevent this, the library uses Phantom Types.

The `Point(CRS)` generator takes a Coordinate Reference System (CRS) type object as an argument. The CRS is an empty struct (`struct WGS84 {}`) that exists solely as a compile-time marker. `Point(WGS84)` and `Point(WebMercator)` generate structurally identical structs (containing `x` and `y` floats), but because their nominal types differ, passing a WGS84 point to a distance function expecting WebMercator instantly triggers a Terra compilation error, guaranteeing coordinate safety with zero runtime overhead.

### 30.3 The Spatial Index as Generic Terra

The core data structure is an R-tree spatial index. It is implemented using the `RTree(GeometryType)` generic pattern.

Inside the generator, Terra vector types are used to implement heavily optimized, SIMD-accelerated bounding-box intersection tests across tree nodes. Because the `GeometryType` is known at compile-time, the index perfectly packs the specific geometries into its nodes. For persistence, the library iterates over the `RTree`'s struct entries using Lua introspection to automatically generate a highly optimized, binary serialization routine, allowing massive indexes to be memory-mapped directly from disk.

### 30.4 The Query DSL

The library exposes a custom query DSL (e.g., `from trees where [t.height > 10.0] select t.location`).

The lexer hook parses this into an AST. The type-checker phase inspects the injected Terra quote (`t.height > 10.0`), verifying that the `tree` struct actually possesses a `height` field of numeric type. The code generator then compiles the AST into a highly specialized query plan. It generates a tight `for` loop that iterates directly over the R-tree, applying the filter as an inline condition, completely eliminating the overhead of standard query interpreter loops or virtual function calls.

### 30.5 Auto-Generated Multi-Language Bindings

Because Terra has full knowledge of the memory layout and signatures of its compiled functions, the Lua orchestrator includes a binding generator script.

When `saveobj` is called to output a `.so` file, the script iterates over the exported Terra functions. It dynamically generates a `libgis.h` C header file and a `libgis.py` Python file containing the precise `ctypes` mappings required to call the library. By simply switching the compilation target via `terralib.newtarget`, the exact same Lua build script emits an optimized WebAssembly `.bc` file and accompanying JavaScript bindings, allowing the GIS library to run natively in the browser.

### 30.6 Performance Numbers

The resulting GIS library demonstrates the raw power of Terra's architecture. The generated R-tree intersection tests match or exceed hand-tuned C++ implementations (like Boost.Geometry) because the SIMD instructions and exact struct layouts are specialized precisely for the geometries being queried.

The dynamic query DSL executes orders of magnitude faster than interpreted GIS languages (like PostGIS Python scripts) because the query plan is compiled into inline machine code. Profiling the generated code via `myfunc:disas()` reveals perfectly vectorized inner loops and completely unrolled coordinate transformations, proving that high-level Lua metaprogramming consistently yields optimal low-level hardware utilization.

---

## Appendix A: Grammar Reference

The Terra grammar is an extension of standard Lua 5.1 syntax. The key additions are the `terra` function definition block, the `struct` definition block, and the metaprogramming operators (`\``,`[ ]`,`quote ... end`).

* **Types:** Identifiers representing type objects, pointers (`&T`), arrays (`T[N]`), vectors (`vector(T,N)`), tuples (`{T1, T2}`), and function signatures (`{T1, T2} -> {R1}`).
* **Statements:** Standard Lua control flow (`if`, `while`, `repeat`, `for`), augmented with `var`, `defer`, and C-style assignment operators.
* **Expressions:** Standard Lua math and logical operators, augmented with address-of (`&`), dereference (`@`), explicit casts (`[T](exp)`), and macro/function application.

## Appendix B: LLVM Intrinsics Quick Reference

Common LLVM intrinsics imported via `terralib.intrinsic` include:

* `llvm.fmuladd.*`: Fused multiply-add.
* `llvm.sqrt.*`: Hardware square root.
* `llvm.cttz.*` / `llvm.ctlz.*`: Count trailing/leading zeros (essential for bitboards).
* `llvm.prefetch`: Inserts a hardware memory prefetch instruction (`prefetch(ptr, rw, locality, cache_type)`).
* `llvm.memcpy.p0i8.p0i8.*`: Highly optimized, architecture-aware bulk memory copy.
* Platform-specific SIMD: e.g., `llvm.x86.sse41.blendvps` (X86), `llvm.aarch64.neon.addp` (ARM).

## Appendix C: Platform Notes

Terra relies on the host OS and the bundled Clang frontend.

* **macOS:** Fully supported. Requires Xcode command line tools for system headers. ARM64 (Apple Silicon) support is robust.
* **Linux:** Fully supported. Integrates natively with standard GNU or musl toolchains.
* **Windows:** Supported via MSVC ABI. Some `includec` behaviors may require specific Visual Studio header paths. Linking against DLLs requires careful symbol management.
* **WASM:** Supported as a cross-compilation target (`wasm32-unknown-unknown`). Output must be processed by Emscripten to link against browser APIs.

## Appendix D: Changelog and Version History

Recent Terra versions have aligned closely with newer LLVM releases (LLVM 11+).

* **Opaque Pointers:** As LLVM transitioned to opaque pointers, Terra's internal IR generation was updated. User-facing Terra pointer types (`&int`) remain strictly typed, but manual bitcode manipulation may require updates.
* **Exotype Overhaul:** The older, ad-hoc callback system for custom types was replaced entirely by the lazy Exotype properties model (e.g., `__getentries`), improving composability and preventing cyclical dependency deadlocks.
* **Mac ARM64:** Full native support for M1/M2 architectures was introduced, resolving earlier Rosetta translation bottlenecks.

---

*Generated from the complete Terra documentation.*
