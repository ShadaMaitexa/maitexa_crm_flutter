# SIM Filtering Fix TODO

## Step 1: Create TODO.md [COMPLETED]

## Step 2: Edit lib/services/call_log_service.dart [COMPLETED]
- Improve getAvailableSims(): prioritize simDisplayName, scan more logs (200), favor carrier names like "vi"/"bsnl", added debug logs.

## Step 3: Edit lib/screens/call_logs_screen.dart [COMPLETED]
- Aligned _applySimFilter() with service logic: prioritize simDisplayName, same carrier/normalized matching.

## Step 4: Test changes
- Run `flutter run` on dual-SIM device.
- Verify both SIMs (vi, bsnl) detected and filter works.

## Step 5: Mark complete and attempt_completion

