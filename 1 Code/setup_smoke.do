* Synthetic test only. Run this file on its own in a fresh Stata session.
* The dataset and every output in this test are temporary.
version 16.0
preserve
clear
input byte record byte artificial_value
1 1
2 2
3 3
end
isid record
quietly summarize artificial_value
assert r(mean) == 2
tempfile testcsv
quietly export delimited using "`testcsv'", replace
quietly import delimited using "`testcsv'", clear varnames(1)
isid record
assert _N == 3
assert record == artificial_value
restore
display as result "ECONTHAKI_SYNTHETIC_SMOKE_OK"
