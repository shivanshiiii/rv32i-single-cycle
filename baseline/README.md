# Preserved comparison baseline

`rv32i_core.v` is copied byte-for-byte from the saved `RV32I_Processor_Starter_v3.zip` recovered for this work. SHA-256:

```text
1c9cb8146259818339b9168758e0fb326b2ce0fe796ab788375cc490c7f80c34
```

The original three RTL testbenches were rerun successfully before optimization. Keep this file unchanged for the v3-to-v4 synthesis comparison and equivalence check. Compile it separately from `rtl/rv32i_core.v`, as both define the same top module.
