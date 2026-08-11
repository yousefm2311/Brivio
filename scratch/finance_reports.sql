CREATE OR REPLACE FUNCTION get_financial_summary()
RETURNS TABLE (
    total_outstanding_minor BIGINT,
    total_collected_minor BIGINT,
    expected_monthly_revenue_minor BIGINT,
    total_adjustments_minor BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE((SELECT SUM(total_minor - amount_paid_minor) FROM invoices WHERE status != 'paid'), 0)::BIGINT as total_outstanding_minor,
        COALESCE((SELECT SUM(amount_minor) FROM receipts), 0)::BIGINT as total_collected_minor,
        COALESCE((SELECT SUM(total_amount_minor) FROM subscription_plans WHERE status = 'active'), 0)::BIGINT as expected_monthly_revenue_minor,
        COALESCE((SELECT SUM(requested_discount_minor) FROM payment_adjustment_requests WHERE status = 'approved'), 0)::BIGINT as total_adjustments_minor;
END;
$$ LANGUAGE plpgsql;
