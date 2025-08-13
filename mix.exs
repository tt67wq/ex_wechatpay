defmodule ExWechatpay.MixProject do
  @moduledoc false
  use Mix.Project

  @name "ex_wechatpay"
  @version "0.3.3"
  @repo_url "https://github.com/tt67wq/ex_wechatpay"
  @description "Elixir SDK for WeChat Pay API v3"

  def project do
    [
      app: :ex_wechatpay,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: @repo_url,
      homepage_url: @repo_url,
      name: @name,
      package: package(),
      description: @description,
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 1.1"},
      {:finch, "~> 0.20", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @repo_url,
        "微信支付官方文档" => "https://pay.weixin.qq.com/wiki/doc/apiv3/index.shtml"
      },
      maintainers: ["tt67wq"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp elixirc_paths(env) when env in ~w(test)a, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md": [title: "概述"],
        "docs/advanced_usage.md": [title: "高级使用指南"],
        "docs/error_handling.md": [title: "错误处理指南"],
        LICENSE: [title: "许可证"]
      ],
      source_ref: "v#{@version}",
      source_url: @repo_url,
      formatters: ["html"],
      groups_for_modules: [
        核心模块: [
          ExWechatpay,
          ExWechatpay.Core,
          ExWechatpay.Supervisor
        ],
        配置管理: [
          ExWechatpay.Config.Helper,
          ExWechatpay.Config.Manager,
          ExWechatpay.Config.Provider,
          ExWechatpay.Config.Schema,
          ExWechatpay.Model.ConfigOption
        ],
        核心组件: [
          ExWechatpay.Core.CertificateManager,
          ExWechatpay.Core.RequestBuilder,
          ExWechatpay.Core.ResponseHandler,
          ExWechatpay.Core.SignatureManager
        ],
        服务接口: [
          ExWechatpay.Service.Refund,
          ExWechatpay.Service.Transaction
        ],
        工具类: [
          ExWechatpay.Exception,
          ExWechatpay.Http,
          ExWechatpay.Model.Http,
          ExWechatpay.Typespecs,
          ExWechatpay.Util
        ]
      ],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        mermaid.initialize({
          startOnLoad: true,
          theme: document.body.className.includes("dark") ? "dark" : "default"
        });

        // 当主题切换时重新渲染图表
        const observer = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            if (mutation.attributeName === "class") {
              mermaid.initialize({
                startOnLoad: true,
                theme: document.body.className.includes("dark") ? "dark" : "default"
              });
              mermaid.init(undefined, document.querySelectorAll(".mermaid"));
            }
          });
        });

        observer.observe(document.body, {
          attributes: true
        });
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""
end
