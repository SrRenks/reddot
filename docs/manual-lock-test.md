# Manual lock test

This test requires a real PAM prompt and can leave the session locked. Run it
from a TTY or a disposable session, with a second terminal available.

## Status

The static flow is covered by `tools/check-lock-static.sh`. A supervised run was
completed on 2026-10-28 with the password and fingerprint split.

### Result

- correct password unlocked the session;
- empty field + Enter + correct fingerprint unlocked the session;
- wrong password returned a readable error and did not start fingerprint;
- wrong fingerprint returned to the password state without an automatic loop;
- Enter on an empty field started a new explicit fingerprint attempt.

The enrolled-print list on the test machine contains four right-hand prints:
little, ring, middle and index. `pam_fprintd` authenticates any enrolled print for
the user; it has no per-finger selector. Remove extra prints with
`fprintd-delete` if only the index finger should remain.

Fingerprint availability is controlled in **Security → Fingerprint unlock**.
The switch is enabled only when `fprintd-list` finds an enrolled finger. Turning
it off leaves password authentication intact and cancels an active fingerprint
attempt.

## Preconditions

- save all work;
- confirm the login password;
- know the TTY escape path for the current machine;
- keep `tools/check-lock-static.sh` passing;
- do not run this automatically from `check.sh`.

## Procedure

1. From a TTY, start the lock daemon in the foreground:

   ```sh
   qs -c lock
   ```

   The process should stay running without opening the pill.

2. In another terminal, trigger the lock:

   ```sh
   ~/.config/hypr/scripts/lock.sh
   ```

3. Confirm that every monitor is covered and that the captured desktop is not
   replaced by a black frame.
4. Confirm that the password field accepts input and that the clock is visible.
5. Submit the wrong password. The field must clear, an error must appear and the
   lock must stay active.
6. Submit the correct password. The lock must collapse and return to the desktop.
7. Trigger the lock again and press Escape. Escape must not bypass PAM.
8. Kill and restart the lock daemon while locked. The session lock must fail
   closed, not reveal the desktop.
9. Trigger the lock without a PAM agent available and confirm that no password is
   stored or logged.

## Expected failures

- wrong password: lock remains;
- missing PAM service: lock remains;
- lock daemon crash: session remains locked by the compositor;
- screenshot capture failure: lock still covers the screen.

## Recovery

If the lock does not accept input, switch to a TTY and terminate the lock daemon
only after confirming that the compositor still holds the session lock. Do not
disable the lock service as a workaround.
