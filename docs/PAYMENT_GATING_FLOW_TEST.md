# Payment Gating Flow Test

Use this checklist after applying all migrations to Supabase.

## Required accounts

- Admin or Staff account with `payments.collect`.
- Teacher account assigned to a real group through `group_teachers`.
- Student account enrolled through the Admin group screen.
- Parent account linked to the student, if parent visibility is being tested.

## Flow

1. Open Admin or Staff portal.
2. Go to Groups and add the student to a group.
3. Enter a non-zero group price and no full discount.
4. Confirm that enrollment result says content is pending cash payment.
5. Sign in as the student.
6. Confirm group content, lessons, boards, schedule, and lesson resources stay locked or hidden.
7. Open student notifications and confirm payment-required notification exists.
8. Sign in as parent.
9. Confirm parent can see payment-required notification and invoices/receipts area.
10. Sign in as Admin or Staff.
11. Open Finance and select the student.
12. Confirm invoice exists and status is unpaid/issued.
13. Record a cash payment for the full remaining amount.
14. Confirm a receipt is generated.
15. Sign in as student again.
16. Confirm group content, schedule, lessons, PDF workspace, and teacher boards are visible.
17. Sign in as teacher.
18. Open Finance.
19. Confirm the group shows paid amount, remaining amount, paid/unpaid student counts.
20. Open the group roster and confirm the student payment status is paid.

## Discount and exemption flow

1. Add another student to the same group with a non-zero price.
2. Sign in as teacher.
3. Open Teacher Finance, open the group, and request a discount for the unpaid student.
4. Sign in as Admin or Staff.
5. Open Finance, Adjustments tab.
6. Approve the request.
7. Confirm enrollment and invoice final price changed.
8. Repeat with discount equal to full price.
9. Confirm enrollment becomes active with `payment_status = exempt`.

## Expected failures to report

- `column ... does not exist`: migration order/schema cache issue.
- `row-level security policy`: missing permission or helper function mismatch.
- `function ... not found`: run `NOTIFY pgrst, 'reload schema';` after migration.
- Student sees content while `pending_payment`: content query is missing access gating.
