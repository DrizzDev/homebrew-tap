class TwinHarness < Formula
  include Language::Python::Virtualenv

  desc "Run an AI agent against a Drizz twin and grade what the twin recorded"
  homepage "https://drizz.dev"
  # Assets live in DrizzDev/releases, the same public repo drizz publishes
  # to, so the source repo can stay private. The tag carries the tool name
  # because plain v0.1.x in that repo belongs to drizz.
  url "https://github.com/DrizzDev/releases/releases/download/twin-harness-v0.2.1/twin_harness-0.2.1.tar.gz"
  sha256 "37093b5b748096adfe9ced39c1db530002d3e6e23b05cb04627faf31c136ff44"
  # Proprietary: this is distributed to Drizz customers, not published.
  license :cannot_represent

  # The package is standard library only, so this formula has no resources and
  # nothing to vendor -- the virtualenv exists to keep four commands off the
  # user's system Python, not to hold dependencies.
  #
  # That isolation is the whole reason to ship this through Homebrew rather
  # than as "pip install". Homebrew Python, Debian 12+, Ubuntu 23.04+ and
  # Fedora 38+ all refuse a system-wide pip install (PEP 668), and the flag
  # that overrides them is called --break-system-packages because that is what
  # it does. A formula sidesteps the argument: brew made that rule and knows
  # how to live inside it.
  depends_on "python@3.14"

  def install
    virtualenv_install_with_resources
  end

  def caveats
    <<~EOS
      twin-harness needs two things before its first run:

        twin-identities.json   your twin's URL and a token for it
        .env                   LLM_BASE / LLM_MODEL / LLM_KEY for your agent

      Copy the examples from the installed package and fill them in:

        twin-test --init

      Worlds and the twin's log of every call (`twin world`, the SDK's
      world.calls()) need only those. PASS/FAIL verdicts come from a Drizz
      grading service -- this build does not carry the grading rules -- and
      need the grading token you were given:

        export TWIN_GRADE_TOKEN=...

      Ask your Drizz contact for the twin URL, the twin token and that one.
    EOS
  end

  test do
    # The commands exist and run. Both of these print a message and exit 1 --
    # usage text and a refusal are failures as far as a shell is concerned --
    # so the expected status is passed explicitly. Leaving it at the default 0
    # is what made this test fail the first time it ran.
    assert_match "twin-test", shell_output("#{bin}/twin-test 2>&1", 1)

    # And the rules are genuinely absent. This is the property that makes the
    # build safe to hand out, so it is worth asserting rather than assuming:
    # a formula built from the wrong tarball would still pass the check above.
    output = shell_output("#{bin}/twin-eval --selftest 2>&1", 1)
    assert_match "does not carry the grading rules", output

    # And it starts up far enough to ask for configuration rather than
    # crashing: the right first-run experience is a sentence, not a traceback.
    assert_match "twin-identities.json", shell_output("#{bin}/twin-eval 2>&1", 1)
  end
end
