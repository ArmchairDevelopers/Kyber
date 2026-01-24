bazel --output_user_root="C:\bz" build --config=release Kyber
xcopy /y /f ".\bazel-bin/Kyber.dll" "%ProgramData%/Kyber/Module/Kyber.dll"