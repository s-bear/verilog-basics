// Functions and macros

`define MAX(a, b) (((a) >= (b)) ? (a) : (b))
`define MIN(a, b) (((a) <= (b)) ? (a) : (b))

/* Ceiling divide */
function integer cdiv;
    input integer a, b;
    begin
        cdiv = a/b;
        if(cdiv*b < a) cdiv = cdiv + 1;
    end
endfunction

/* Ceil(log2(a)) */
function integer clog2;
    input integer a;
    begin
        a = a - 1;
        for(clog2 = 0; a > 0; clog2 = clog2 + 1) a = a >> 1;
    end
endfunction