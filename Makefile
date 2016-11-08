PROJECT = rabbitmq_cli
VERSION ?= 0.0.1

BUILD_DEPS = rabbit_common amqp_client amqp json

dep_amqp = git https://github.com/pma/amqp.git master
dep_json = hex 1.0.0

DEP_PLUGINS = rabbit_common/mk/rabbitmq-plugin.mk

TEST_FILE ?= ""

include rabbitmq-components.mk
include erlang.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

ESCRIPTS = escript/rabbitmqctl \
	   escript/rabbitmq-plugins \
	   escript/rabbitmq-diagnostics

deps::
	mix deps.get
	mix deps.compile

app:: $(ESCRIPTS)
	@:

rabbitmqctl_srcs := mix.exs \
		    $(shell find config lib -name "*.ex" -o -name "*.exs")

escript/rabbitmqctl: $(rabbitmqctl_srcs)
	mix escript.build

escript/rabbitmq-plugins escript/rabbitmq-diagnostics:
	ln -sf rabbitmqctl $@

rel:: $(ESCRIPTS)
	@:

tests:: all
	mix test --trace

test:: all
	mix test --trace $(TEST_FILE)

clean::
	rm -f $(ESCRIPTS)
	mix clean

repl:
	iex -S mix
