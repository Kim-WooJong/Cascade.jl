# Third-party notices

Cascade original code is licensed under LICENSE (MIT). The identified external
portions below retain their upstream copyright and terms; Cascade MIT does not
replace them. Dependency licenses remain with their respective packages.

## fdlibm / FreeBSD error function

`src/Corrections/erf.jl` is a Julia adaptation of `s_erf.c`. Source:
https://raw.githubusercontent.com/JuliaMath/openlibm/master/src/s_erf.c
The implementation language and surrounding interface were changed.

```text
Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.

Developed at SunPro, a Sun Microsystems, Inc. business.
Permission to use, copy, modify, and distribute this
software is freely granted, provided that this notice
is preserved.
```

## UnROOT 0.11.11 test source primitives

`test/skim_entrycount/source_primitives.jl` contains source slices adapted for a
synthetic IOBuffer fixture. The copied source-file hashes and slice inventory
remain in `test/skim_entrycount/PRIMITIVE_SOURCES.json`.
Sources: https://github.com/JuliaHEP/UnROOT.jl/tree/v0.11.11/src
License: https://raw.githubusercontent.com/JuliaHEP/UnROOT.jl/v0.11.11/LICENSE
The module boundary and physical I/O seam are adapted for the fixture.

```text
MIT License

Copyright (c) 2019 Tamas Gal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## correctionlib 2.8.0 schema and TFormula oracle cases

`tools/oracle/schema_cases.py` adapts cases from correctionlib 2.8.0 tests.
Sources: https://github.com/cms-nanoAOD/correctionlib/tree/v2.8.0/tests
License: https://raw.githubusercontent.com/cms-nanoAOD/correctionlib/v2.8.0/LICENSE
The cases are collected into a standalone oracle-input generator.

```text
BSD 3-Clause License

Copyright (c) 2021, Nick Smith.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the vector package developers nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## xxHash algorithm

`src/Corrections/xxhash64.jl` implements XXH64 for little-endian 64-bit words.
Reference: https://github.com/Cyan4973/xxHash
Upstream notice retained with the compatibility implementation:

```text
xxHash Library
Copyright (c) 2012-2021 Yann Collet
All rights reserved.

BSD 2-Clause License (https://www.opensource.org/licenses/bsd-license.php)

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## PCG generator

The PCG32 generator in `src/Corrections/pcg32.jl` follows the pcg-cpp
oneseq_xsh_rr_64_32 generator. Upstream offers MIT terms:
https://raw.githubusercontent.com/imneme/pcg-cpp/master/LICENSE-MIT.txt

```text
MIT License

Copyright (c) 2014-2017 Melissa O'Neill and PCG Project contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Mathematical and external behavioral references

The uniform/normal transforms name libstdc++ and correctionlib as behavioral
comparison targets. The HistFactory/pyhf interpolation names identify the
mathematical conventions implemented in `src/Fit/interpolation.jl`; pyhf is
also used as an external oracle. These references do not relicense or bundle
the respective external libraries. Native ROOT and all runtime dependencies
retain their upstream license terms.

Calibration payloads, certification masks and datasets are separate inputs.
Their source and redistribution terms must be checked independently of the
Cascade code license; the project MIT license does not authorize their reuse.
