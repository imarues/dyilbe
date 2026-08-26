# iKiraPlus V8 Framework Edition

This edition keeps the original V8 protection logic while packaging the five
secondary guards as genuine iOS dynamic frameworks.

Build products:
- `iKiraPlus.dylib`
- `UIDisplayServices.dylib`
- `UIInfrastructure.framework`
- `CoreLifecycle.framework`
- `ProcessServices.framework`
- `ProcessSupport.framework`
- `SystemEnvironment.framework`

Only `iKiraPlus.dylib` and `UIDisplayServices.dylib` are directly injected.
`UIDisplayServices` loads the five framework executables from the app's
`Frameworks` directory.
