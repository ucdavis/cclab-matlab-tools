function [T] = fpwrapper(X, C)
%FPWRAPPER Process X through each function in the chain defined by C. 
%   C should be a 1-D cell array, each element should be a function handle.
%   T=C{n}(c{n-1}(c{...}(c{2}(c{1}(X)))))
    arguments (Input)
        X   {mustBeNumeric}
        C   cell {mustBeCellArrayWithFuncPtrs}
    end
    
    arguments (Output)
        T
    end

    T = X;
    for i=1:length(C)
        T = C{i}(T);
    end
end



% Custom validation function
function mustBeCellArrayWithFuncPtrs(C)

if ~iscell(C) || ~isvector(C) || ~all(cellfun(@(x) isa(x, 'function_handle'), C))
        eid = 'Type:notCell';
        msg = 'Expecting cell array of fptrs';
        error(eid, msg);
    end
end