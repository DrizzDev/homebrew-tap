class TwinHarness < Formula
  include Language::Python::Virtualenv

  desc "Run an AI agent against a Drizz twin and grade what the twin recorded"
  homepage "https://drizz.dev"
  # Assets live in DrizzDev/releases, the same public repo drizz publishes
  # to, so the source repo can stay private. The tag carries the tool name
  # because plain v0.1.x in that repo belongs to drizz.
  url "https://github.com/DrizzDev/releases/releases/download/twin-harness-v0.10.3/twin_harness-0.10.3.tar.gz"
  sha256 "1caa1a5b7cd72556b05f959d6870bb1e022cbb2605b0589984b1283286794c2e"
  # Business Source License 1.1: LICENSE and NOTICE inside the tarball.
  license "BUSL-1.1"

  # Only this tool's own tags: "latest" in DrizzDev/releases is drizz's.
  livecheck do
    url :stable
    regex(/^twin-harness-v?(\d+(?:\.\d+)+)$/i)
  end

  # The harness and twin-core, the one package it needs (the formats and
  # helpers it shares with Drizz's grading service), both standard library
  # only. The virtualenv keeps them off the user's system Python, which
  # Homebrew Python, Debian 12+, Ubuntu 23.04+ and Fedora 38+ all protect
  # (PEP 668).
  depends_on "python@3.14"

  resource "twin-core" do
    url "https://github.com/DrizzDev/releases/releases/download/twin-harness-v0.10.3/twin_core-0.10.3.tar.gz"
    sha256 "d795d33b6e13b43fe81f834012dceb9a693b7a23e6a7ae37a0983032f4c3864c"
  end

  def install
    virtualenv_install_with_resources
  end

  def caveats
    <<~EOS
      Sign in once; a key for the twin is kept for this machine:

        twin login

      Then write the example tests and your agent's model settings:

        twin-test --init       # tests/, .env.example (LLM_BASE / LLM_MODEL / LLM_KEY)

      PASS/FAIL verdicts come from Drizz's grading service -- this build does
      not carry the grading rules -- and need the grading token you were given:

        export TWIN_GRADE_TOKEN=...
    EOS
  end

  test do
    assert_match "twin-test #{version} (twin-core #{version})", shell_output("#{bin}/twin-test --version")

    # The example test it writes is valid: the harness reads and checks it
    # without a twin, a model or a network.
    system bin/"twin-test", "--init"
    assert_match "ok", shell_output("#{bin}/twin-test --check tests/move-conflict.md")

    # The grading rules are genuinely absent -- the property that makes the
    # build safe to hand out: their tools say where they went instead.
    assert_match "moved to twin-grade", shell_output("#{bin}/twin-eval selftest 2>&1", 2)

    # And without configuration it asks for it in a sentence, not a traceback.
    assert_match "twin-identities.json", shell_output("#{bin}/twin-eval 2>&1", 1)
  end
end
