class TwinHarness < Formula
  include Language::Python::Virtualenv

  desc "Run an AI agent against a Drizz twin and grade what the twin recorded"
  homepage "https://drizz.dev"
  # Assets live in DrizzDev/releases, the same public repo drizz publishes
  # to, so the source repo can stay private. The tag carries the tool name
  # because plain v0.1.x in that repo belongs to drizz.
  url "https://github.com/DrizzDev/releases/releases/download/twin-harness-v0.10.11/twin_harness-0.10.11.tar.gz"
  sha256 "d374cacc090a27d2ee64aae7cbf28fafff53bb28eac6a23adcb000a57364c316"
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
    url "https://github.com/DrizzDev/releases/releases/download/twin-harness-v0.10.11/twin_core-0.10.11.tar.gz"
    sha256 "04e1a4e53846c594822bb11aa3844483ae11c6360d1ec7b6069aeaa84a1e336f"
  end

  def install
    virtualenv_install_with_resources
    generate_completions_from_executable(bin/"twin", "completion")
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

    # And without configuration it asks for it in a sentence, not a traceback
    # (exit 2: a setup error, `twin help exit-codes`).
    assert_match "twin-identities.json", shell_output("#{bin}/twin-eval 2>&1", 2)
  end
end
