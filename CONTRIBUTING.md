# Contributing

Keep changes small and compatible with Microbot WoW 1.12.1, Interface 11200, and Lua 5.0.

## Before opening a pull request

1. State the exact client build you tested.
2. Do not add client MPQs, extracted FrameXML, executables, account data, logs, or local paths.
3. Keep protected movement calls in the generated trusted FrameXML binding payload, not addon Lua.
4. Never edit `bindings-cache.wtf` or call `SaveBindings`.
5. Preserve Shift + left and Shift + right as native fallbacks.
6. Run:

   ```bash
   python -m pip install --require-hashes -r requirements-dev.txt
   python scripts/validate.py
   python scripts/build_release.py
   ```

7. Compile addon and patch Lua bodies with Lua 5.0.3.
8. Test the resulting addon ZIP and locally generated MPQ in an isolated client before using a normal install.

## Bug reports

Include the client version, exact input sequence, movement mode, combat state, and Lua error text. Remove account names, credentials, server tokens, screenshots with private data, and local paths.
