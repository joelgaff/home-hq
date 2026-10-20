require "test_helper"
require "open3"
require "tmpdir"

# bin/webview-check rejects CSS and JavaScript the frame's Android System WebView 106 cannot run
# (docs/ui-spec.md §6): 4/8-digit hex colours, oklch(), color-mix(), CSS nesting, dvh units,
# inset shorthand, and ES2023+ (toSorted, RegExp v flag). bin/ci runs it over app/assets and
# app/javascript so a slip never reaches the wall.
class WebviewCheckTest < ActiveSupport::TestCase
  def check(files)
    Dir.mktmpdir do |dir|
      files.each { |name, body| File.write(File.join(dir, name), body) }
      out, err, status = Open3.capture3(Rails.root.join("bin/webview-check").to_s, dir)
      [ status.exitstatus, out + err ]
    end
  end

  test "clean assets pass" do
    code, _ = check("ok.css" => ".a { color: #FF9500; background: rgb(17 17 17 / .5); }\n",
                    "ok.js" => "const a = [3, 1].slice().sort();\n")
    assert_equal 0, code
  end

  test "an 8-digit or 4-digit hex colour fails" do
    code, out = check("bad.css" => ".a { color: #ffffffbf; }\n.b { color: #0000; }\n")
    assert_equal 1, code
    assert_match(/bad\.css:1.*#ffffffbf/, out)
    assert_match(/bad\.css:2.*#0000/, out)
  end

  test "oklch, color-mix, dvh and inset fail" do
    code, out = check("bad.css" => <<~CSS)
      .a { color: oklch(60% 0.1 200); }
      .b { background: color-mix(in srgb, red, blue); }
      .c { height: 100dvh; }
      .d { inset: 0; }
    CSS
    assert_equal 1, code
    %w[oklch color-mix dvh inset].each { |word| assert_match(word, out) }
  end

  test "rules inside @media and @supports blocks are not nesting" do
    code, out = check("ok.css" => "@media (max-width: 700px) {\n  .a { color: red; }\n  .b { color: blue; }\n}\n@supports (display: grid) { .c { display: grid; } }\n")
    assert_equal 0, code, out
  end

  test "CSS nesting fails" do
    code, out = check("bad.css" => ".a {\n  color: red;\n  .b { color: blue; }\n}\n")
    assert_equal 1, code
    assert_match(/nesting/, out)
  end

  test "ES2023+ JavaScript fails" do
    code, out = check("bad.js" => "const s = list.toSorted();\nconst r = /[\\p{L}--[a-z]]/v;\n")
    assert_equal 1, code
    assert_match(/toSorted/, out)
    assert_match(/RegExp v flag/, out)
  end

  test "the real assets pass" do
    out, err, status = Open3.capture3(Rails.root.join("bin/webview-check").to_s,
      Rails.root.join("app/assets/stylesheets").to_s, Rails.root.join("app/javascript").to_s)
    assert status.success?, out + err
  end
end
