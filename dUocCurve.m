function dUoc = UocCurve(SOC)
    global best_coeffs_chg;

    n = length(best_coeffs_chg);
    dUoc = 0;
    for i = 1:n-1
        exponent = n - i;
        coeff = best_coeffs_chg(i);
        dUoc = dUoc + coeff * exponent * SOC.^(exponent - 1);
    end
end