.PHONY: help setup build lint fmt test test.watch repl deps.get deps.update deps.update.all deps.clean deps.compile deps.tree

.DEFAULT_GOAL := help

## 核心指令
help: ## 显示所有指令说明
		@awk 'BEGIN {FS = ":.*?## "}; \
		/^[a-zA-Z0-9_.-]+:.*?## / { \
			printf "\033[36m%-18s\033[0m %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST) | sort

setup: ## 初始化开发环境
	@mix do deps.get, compile

build: ## 编译项目
	@mix compile

## 代码质量
lint: ## 静态代码检查
	@mix format --check-formatted

fmt: ## 自动格式化代码
	@mix format

test: ## 运行测试套件
	@mix test

test.watch: ## 监听模式运行测试
	@mix test.watch

## 开发工具
repl: ## 启动交互式环境
	@iex -S mix

## 依赖管理指令
deps.get: ## 获取所有依赖
	@mix deps.get

deps.update: ## 更新指定依赖
	@mix deps.update $(filter-out $@,$(MAKECMDGOALS))

deps.update.all: ## 更新所有依赖
	@mix deps.update --all

deps.clean: ## 清理未使用的依赖
	@mix deps.clean --unused

deps.compile: ## 编译项目依赖
	@mix deps.compile

deps.tree: ## 显示依赖树状结构
	@mix deps.tree
