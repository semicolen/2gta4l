# Additional desktop users

The image's `tablet` account belongs to `audio`, `video`, `netdev` and `plugdev`.
An account created through GNOME Settings does not automatically receive these
groups. In particular, the private accelerated session needs read/write access
to `/dev/kgsl-3d0` and `/dev/ion`, both owned by `video` with mode 0660.

To give an additional user the same hardware access, run these commands as an
administrator, replacing `USERNAME` with that account's name:

```sh
sudo addgroup USERNAME audio
sudo addgroup USERNAME video
sudo addgroup USERNAME netdev
sudo addgroup USERNAME plugdev
```

Log out and start a fresh login so processes receive the new group membership.
These commands grant device access and do not change the account password or
grant administrator membership. The image assembly gives these hardware groups
to the default account; it does not automatically modify all future accounts.
On the tablet, the newly created user's KGSL/ION access checks change from
denied to allowed after this correction. The user confirms the new account's
desktop and apps open after a fresh login.
