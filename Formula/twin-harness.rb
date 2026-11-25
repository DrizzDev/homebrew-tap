class TwinHarness < Formula
  include Language::Python::Virtualenv

  desc "Run an AI agent against a Drizz twin and grade what the twin recorded"
  homepage "https://drizz.dev"
  # Assets live in DrizzDev/releases, the same public repo drizz publishes
  # to, so the source repo can stay private. The tag carries the tool name
  # because plain v0.1.x in that repo belongs to drizz.
  url "https://github.com/DrizzDev/releases/releases/download/twin-harness-v0.11.6/twin_harness-0.11.6.tar.gz"
  sha256 "2a4fcb27ea6f88879dd5359a4b40c982dca602fa4d46f0c9e1a5b37598252bdc"
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

  # The build tools for the two packages above, as wheels: pure Python, so
  # nothing is compiled and nothing is fetched while installing. Left to pip,
  # Homebrew's --no-binary=:all: builds hatchling and everything it needs --
  # setuptools, setuptools-scm, flit-core ... -- from source, from PyPI, on the
  # user's Mac, and one failure anywhere in that chain fails the install
  # (seen 2026-11-17: "Failed to build 'hatchling'"). Used to build, then gone:
  # none of them is in the installed virtualenv.
  resource "hatchling" do
    url "https://files.pythonhosted.org/packages/32/64/4afe5dd77b2939a93e8c9513f8082dbd049ecba9c1484a379a0f6ae29d6b/hatchling-1.33.0-py3-none-any.whl"
    sha256 "415290b84f464d2884303fca8974d38e7b85579069fab02a15db0828fbb1446d"
  end

  resource "packaging" do
    url "https://files.pythonhosted.org/packages/63/34/ba1c580383c9eada3711951fef0795c80b829a078d72188184bcab9dd527/packaging-26.3-py3-none-any.whl"
    sha256 "d7193f7c8e4e93f444fde0262bf90af30e16fa0ad0ad44cb553c87339b23cd1c"
  end

  resource "pathspec" do
    url "https://files.pythonhosted.org/packages/f1/d9/7fb5aa316bc299258e68c73ba3bddbc499654a07f151cba08f6153988714/pathspec-1.1.1-py3-none-any.whl"
    sha256 "a00ce642f577bf7f473932318056212bc4f8bfdf53128c78bbd5af0b9b20b189"
  end

  resource "pluggy" do
    url "https://files.pythonhosted.org/packages/40/9e/2b38731e0fc536806f16490e1a12d7f0dc2a1235aa8cc07bcc75416a7daa/pluggy-1.7.0-py3-none-any.whl"
    sha256 "7dd7b0d8832ba3cb632c306926ded123429211b83641b35dc5c41ad2d34f9bec"
  end

  resource "tomlkit" do
    url "https://files.pythonhosted.org/packages/da/46/7d84138a60a8bd796825b2d38ebe92d0d16501ca57d501b7c5d677401bbc/tomlkit-0.15.2-py3-none-any.whl"
    sha256 "05562412163a3037b94497385fb7f9204c637bc605af7a48199e41cf2272f437"
  end

  resource "trove-classifiers" do
    url "https://files.pythonhosted.org/packages/30/81/0da8afb52a71d0a4f2bd3152357b1a441e393b286374802b9d3addab4ab5/trove_classifiers-2026.9.21.13-py3-none-any.whl"
    sha256 "8b1ff4f9c191b1040b71c37f1e445ab99732911e3cd91de52838453a854d7a17"
  end

  resource "twin-core" do
    url "https://github.com/DrizzDev/releases/releases/download/twin-harness-v0.11.6/twin_core-0.11.6.tar.gz"
    sha256 "58b938a9533d3c236a869f3169fb256a7f053d8a5aedaf0a7040c6e11ca6a59b"
  end

  BUILD_TOOLS = %w[hatchling packaging pathspec pluggy tomlkit trove-classifiers].freeze

  def install
    # the build tools, put where the build finds them and nowhere else
    tools = buildpath/"build-tools"
    wheels = BUILD_TOOLS.map do |name|
      r = resource(name) # fetched by brew before install, with its sha256 checked
      whl = buildpath/File.basename(r.url)
      cp r.cached_download, whl
      whl
    end
    system formula_opt_bin("python@3.14")/"python3.14", "-m", "pip", "install", "--no-deps", "--no-index",
           "--no-compile", "--disable-pip-version-check", "--target", tools, *wheels
    ENV.prepend_path "PYTHONPATH", tools

    venv = virtualenv_create(libexec, "python3.14")
    venv.pip_install resource("twin-core"), build_isolation: false
    venv.pip_install_and_link buildpath, build_isolation: false
    generate_completions_from_executable(bin/"twin", "completion")
  end

  def caveats
    <<~EOS
      Get started in 3 steps:

        1. Sign in (your browser opens):

             twin login

        2. See the twins you can use:

             twin --list

        3. Make your first world and connect your agent, step by step:

             https://docs.drizz.dev/twins/getting-started/quickstart
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
