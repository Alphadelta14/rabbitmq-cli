PROJECT = rabbitmq_cli

BUILD_DEPS = rabbit_common amqp_client

DEP_PLUGINS = rabbit_common/mk/rabbitmq-plugin.mk

VERBOSE_TEST ?= true

ifeq ($(VERBOSE_TEST),true)
MIX_TEST = mix test --trace
else
MIX_TEST = mix test --max-cases=1
endif

include rabbitmq-components.mk
include erlang.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

ESCRIPTS = escript/rabbitmqctl \
	   escript/rabbitmq-plugins \
	   escript/rabbitmq-diagnostics

$(HOME)/.mix/archives/hex-*:
	mix local.hex --force

hex: $(HOME)/.mix/archives/hex-*

deps:: hex
	mix deps.get
	mix deps.compile

app:: $(ESCRIPTS)
	@:

rabbitmqctl_srcs := mix.exs \
		    $(shell find config lib -name "*.ex" -o -name "*.exs")

ebin: $(rabbitmqctl_srcs) hex
	mix deps.get
	mix deps.compile
	rm -rf ebin
	mix compile
	mkdir -p ebin
	cp -r _build/dev/lib/rabbitmqctl/ebin/* ebin

escript/rabbitmqctl: ebin
	mix escript.build

escript/rabbitmq-plugins escript/rabbitmq-diagnostics: escript/rabbitmqctl
	ln -sf rabbitmqctl $@

rel:: $(ESCRIPTS)
	@:

tests:: all
	$(MIX_TEST)

test:: all
	$(MIX_TEST) $(TEST_FILE)

clean:: hex
	rm -f $(ESCRIPTS)
	rm -rf ebin
	mix clean

repl:
	iex -S mix
