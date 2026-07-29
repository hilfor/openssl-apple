import Foundation
import FMake

OutputLevel.default = .error

// --deprecated matters from 3.0 on. build-libssl.sh adds `no-deprecated` unless
// told otherwise, which cost nothing under 1.1.1 because the APIs it controls
// were current there. Under 3.x it drops them from the library entirely, and
// libssh2 imports two: ENGINE_load_builtin_engines and
// ENGINE_register_all_complete. Those imports are lazy-bound, so omitting them
// is not a link error and does not fail launch either -- the consuming app
// builds, ships, passes its tests, and aborts under dyld the first time the
// missing function is actually called.
//
// This flag does not make a 1.1.1-era libssh2 loadable on its own. That binary
// also imports EVP_PKEY_id, which 3.0 renamed to EVP_PKEY_get_id and left
// behind only as a header macro, so no build option can export it. Linking
// libssh2 against 3.x requires recompiling libssh2.
try sh("./build-libssl.sh --deprecated")

try sh("./create-openssl-framework.sh static")

try cd("xcframeworks/static") {
    try sh("zip --symlinks -r ../../openssl-static.xcframework.zip openssl.xcframework")
}

try sh("zip --symlinks -r openssl-libs.zip libs")

try sh("./create-openssl-framework.sh dynamic")

try cd("xcframeworks/dynamic") {
    try sh("zip --symlinks -r ../../openssl-dynamic.xcframework.zip openssl.xcframework")
}

try cd("frameworks/static") {
    try sh("zip --symlinks -r ../../openssl-static.frameworks.zip .")
}

try cd("frameworks/dynamic") {
    try sh("zip --symlinks -r ../../openssl-dynamic.frameworks.zip .")
}

// Build provenance. The tag says which commit of this fork published a release,
// but not which OpenSSL it built or which toolchain built it -- and those do
// differ: a local build on an Xcode beta and a CI build bake different SDK
// versions into LC_BUILD_VERSION. Recording them here makes an artifact
// answerable for itself rather than only through its tag.
func capture(_ command: String) -> String {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: "/bin/sh")
  p.arguments = ["-c", command]
  let pipe = Pipe()
  p.standardOutput = pipe
  do { try p.run() } catch { return "unknown" }
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  p.waitUntilExit()
  let out = String(decoding: data, as: UTF8.self)
    .trimmingCharacters(in: .whitespacesAndNewlines)
  return out.isEmpty ? "unknown" : out
}

let opensslVersion = capture(
  #"awk '/define OPENSSL_VERSION_TEXT/ && !/-fips/ {print $5; exit}' include/openssl/opensslv.h"#)
let forkCommit = capture("git rev-parse HEAD")
let xcodeVersion = capture("xcodebuild -version | tr '\\n' ' '")
let iosSDK = capture("xcrun --sdk iphoneos --show-sdk-version")

let releaseMD =
  """

    OpenSSL \(opensslVersion), built from openssl-apple \(forkCommit).

    | Build input | Value |
    | ----------- | ----- |
    | OpenSSL     | \(opensslVersion) |
    | Fork commit | \(forkCommit) |
    | Toolchain   | \(xcodeVersion) |
    | iOS SDK     | \(iosSDK) |

    | File                            | SHA 256                                             |
    | ------------------------------- |:---------------------------------------------------:|
    | openssl-static.xcframework.zip  | \(try sha(path: "openssl-static.xcframework.zip"))  |
    | openssl-dynamic.xcframework.zip | \(try sha(path: "openssl-dynamic.xcframework.zip")) |
    | openssl-static.frameworks.zip   | \(try sha(path: "openssl-static.frameworks.zip"))   |
    | openssl-dynamic.frameworks.zip  | \(try sha(path: "openssl-dynamic.frameworks.zip"))  |
    | openssl-libs.zip                | \(try sha(path: "openssl-libs.zip")) |

  """

try write(content: releaseMD, atPath: "release.md")
