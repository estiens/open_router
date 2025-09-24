# frozen_string_literal: true

require "spec_helper"

RSpec.describe "OpenRouter Prompt Templates", :vcr do
  let(:client) do
    OpenRouter::Client.new(access_token: ENV["OPENROUTER_API_KEY"])
  end

  describe "basic prompt templates" do
    it "uses simple variable interpolation", vcr: { cassette_name: "prompt_template_basic" } do
      template = OpenRouter::PromptTemplate.new(
        "Hello {{name}}, welcome to {{location}}!"
      )

      prompt = template.render(name: "Alice", location: "San Francisco")
      expect(prompt).to eq("Hello Alice, welcome to San Francisco!")

      response = client.complete(
        [{ role: "user", content: prompt }],
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 50 }
      )

      expect(response).to be_a(OpenRouter::Response)
      expect(response.content).not_to be_empty
    end

    it "handles multi-line templates", vcr: { cassette_name: "prompt_template_multiline" } do
      template = OpenRouter::PromptTemplate.new(<<~TEMPLATE)
        You are a {{role}} assistant.

        Task: {{task}}
        Context: {{context}}

        Please provide a helpful response.
      TEMPLATE

      prompt = template.render(
        role: "helpful",
        task: "explain quantum computing",
        context: "beginner audience"
      )

      response = client.complete(
        [{ role: "system", content: prompt }, { role: "user", content: "Explain quantum computing" }],
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 150 }
      )

      expect(response.content.downcase).to include("quantum")
    end
  end

  describe "few-shot prompt templates" do
    it "creates few-shot examples", vcr: { cassette_name: "prompt_template_few_shot" } do
      template = OpenRouter::PromptTemplate.new(
        system: "You are a sentiment analyzer. Classify text as positive, negative, or neutral.",
        few_shot_examples: [
          { input: "I love this product!", output: "positive" },
          { input: "This is terrible.", output: "negative" },
          { input: "It's okay, nothing special.", output: "neutral" }
        ],
        user_template: "Classify: {{text}}"
      )

      messages = template.to_messages(text: "This is amazing!")

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 10 }
      )

      expect(messages).to be_an(Array)
      expect(messages.first[:role]).to eq("system")
      expect(response.content.downcase).to include("positive")
    end

    it "handles complex few-shot patterns", vcr: { cassette_name: "prompt_template_complex_few_shot" } do
      template = OpenRouter::PromptTemplate.new(
        system: "You are a code translator. Convert Python to JavaScript.",
        few_shot_examples: [
          {
            input: "print('Hello World')",
            output: "console.log('Hello World');"
          },
          {
            input: "x = [1, 2, 3]\nfor i in x:\n    print(i)",
            output: "const x = [1, 2, 3];\nfor (const i of x) {\n    console.log(i);\n}"
          }
        ],
        user_template: "Convert this Python code: {{code}}"
      )

      messages = template.to_messages(code: "def greet(name):\n    return f'Hello {name}'")

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 200 }
      )

      expect(response.content).to include("function")
      expect(response.content).to include("greet")
    end
  end

  describe "chat formatting templates" do
    it "formats multi-turn conversations", vcr: { cassette_name: "prompt_template_chat_format" } do
      template = OpenRouter::PromptTemplate.new(
        system: "You are a {{role}} assistant specializing in {{specialty}}.",
        conversation: [
          { role: "user", template: "{{user_message_1}}" },
          { role: "assistant", template: "{{assistant_response_1}}" },
          { role: "user", template: "{{user_message_2}}" }
        ]
      )

      messages = template.to_messages(
        role: "helpful",
        specialty: "programming",
        user_message_1: "What is Python?",
        assistant_response_1: "Python is a programming language known for its simplicity.",
        user_message_2: "Can you show me a Hello World example?"
      )

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 100 }
      )

      expect(messages.length).to eq(4) # system + 3 conversation messages
      expect(messages[0][:role]).to eq("system")
      expect(messages[1][:role]).to eq("user")
      expect(messages[2][:role]).to eq("assistant")
      expect(messages[3][:role]).to eq("user")
      expect(response.content).to include("print")
    end

    it "handles dynamic conversation length", vcr: { cassette_name: "prompt_template_dynamic_chat" } do
      template = OpenRouter::PromptTemplate.new(
        system: "You are a helpful assistant.",
        conversation: "{{conversation_history}}"
      )

      conversation_history = [
        { role: "user", content: "What's 2+2?" },
        { role: "assistant", content: "2+2 equals 4." },
        { role: "user", content: "What about 3+3?" }
      ]

      messages = template.to_messages(conversation_history: conversation_history)

      response = client.complete(
        messages,
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 30 }
      )

      expect(messages.length).to eq(4) # system + 3 conversation messages
      expect(response.content).to include("6")
    end
  end

  describe "conditional templates" do
    it "handles conditional content", vcr: { cassette_name: "prompt_template_conditional" } do
      template = OpenRouter::PromptTemplate.new(<<~TEMPLATE)
        You are a customer service assistant.
        {{#if urgent}}
        ⚠️ URGENT REQUEST - Please prioritize this response.
        {{/if}}

        Customer inquiry: {{inquiry}}
        {{#if customer_tier}}
        Customer tier: {{customer_tier}}
        {{/if}}

        Please provide helpful assistance.
      TEMPLATE

      # Test with urgent flag
      prompt_urgent = template.render(
        urgent: true,
        inquiry: "My account is locked",
        customer_tier: "Premium"
      )

      response = client.complete(
        [{ role: "system", content: prompt_urgent }, { role: "user", content: "Help me" }],
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 100 }
      )

      expect(prompt_urgent).to include("⚠️ URGENT")
      expect(prompt_urgent).to include("Premium")
      expect(response).to be_a(OpenRouter::Response)
    end

    it "excludes conditional content when false", vcr: { cassette_name: "prompt_template_conditional_false" } do
      template = OpenRouter::PromptTemplate.new(<<~TEMPLATE)
        You are a customer service assistant.
        {{#if urgent}}
        ⚠️ URGENT REQUEST - Please prioritize this response.
        {{/if}}

        Customer inquiry: {{inquiry}}

        Please provide helpful assistance.
      TEMPLATE

      # Test without urgent flag
      prompt_normal = template.render(
        urgent: false,
        inquiry: "General question about pricing"
      )

      response = client.complete(
        [{ role: "system", content: prompt_normal }, { role: "user", content: "What are your prices?" }],
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 100 }
      )

      expect(prompt_normal).not_to include("⚠️ URGENT")
      expect(prompt_normal).to include("General question")
      expect(response).to be_a(OpenRouter::Response)
    end
  end

  describe "template composition" do
    it "composes multiple templates", vcr: { cassette_name: "prompt_template_composition" } do
      base_template = OpenRouter::PromptTemplate.new(
        "You are a {{role}} assistant."
      )

      task_template = OpenRouter::PromptTemplate.new(
        "Task: {{task}}\nRequirements: {{requirements}}"
      )

      composed_prompt = [
        base_template.render(role: "technical"),
        task_template.render(
          task: "code review",
          requirements: "focus on security and performance"
        )
      ].join("\n\n")

      response = client.complete(
        [{ role: "system", content: composed_prompt }, { role: "user", content: "Review this code: print('hello')" }],
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 150 }
      )

      expect(composed_prompt).to include("technical assistant")
      expect(composed_prompt).to include("code review")
      expect(response.content).to include("code")
    end

    it "uses nested template variables", vcr: { cassette_name: "prompt_template_nested" } do
      template = OpenRouter::PromptTemplate.new(<<~TEMPLATE)
        You are {{user.role}} working at {{user.company}}.

        Project: {{project.name}}
        Priority: {{project.priority}}

        {{#each tasks}}
        - Task {{@index}}: {{this.name}} ({{this.status}})
        {{/each}}

        Please provide an update.
      TEMPLATE

      data = {
        user: { role: "developer", company: "TechCorp" },
        project: { name: "API Redesign", priority: "High" },
        tasks: [
          { name: "Database schema", status: "completed" },
          { name: "API endpoints", status: "in progress" }
        ]
      }

      prompt = template.render(data)

      response = client.complete(
        [{ role: "system", content: prompt }, { role: "user", content: "What's the status?" }],
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 150 }
      )

      expect(prompt).to include("TechCorp")
      expect(prompt).to include("API Redesign")
      expect(prompt).to include("Database schema")
      expect(response).to be_a(OpenRouter::Response)
    end
  end

  describe "template with tools integration" do
    let(:calculator_tool) do
      OpenRouter::Tool.define do
        name "calculate"
        description "Perform calculations"
        parameters do
          string "expression", required: true, description: "Mathematical expression"
        end
      end
    end

    it "integrates templates with tool calling", vcr: { cassette_name: "prompt_template_with_tools" } do
      template = OpenRouter::PromptTemplate.new(
        system: "You are a math tutor. Help solve: {{problem}}",
        user_template: "Please calculate: {{expression}}"
      )

      messages = template.to_messages(
        problem: "basic arithmetic",
        expression: "25 * 4 + 10"
      )

      response = client.complete(
        messages,
        model: "openai/gpt-4o-mini",
        tools: [calculator_tool],
        tool_choice: "auto",
        extras: { max_tokens: 200 }
      )

      expect(messages[0][:content]).to include("math tutor")
      expect(messages[1][:content]).to include("25 * 4 + 10")
      expect(response).to be_a(OpenRouter::Response)
    end
  end

  describe "template with structured outputs" do
    let(:analysis_schema) do
      OpenRouter::Schema.define("analysis_result") do
        string :summary, required: true, description: "Brief summary"
        number :confidence, required: true, description: "Confidence score 0-1"
        array :key_points, items: { type: "string" }, description: "Main points"
      end
    end

    let(:response_format) do
      {
        type: "json_schema",
        json_schema: analysis_schema.to_h
      }
    end

    it "combines templates with structured outputs", vcr: { cassette_name: "prompt_template_structured" } do
      template = OpenRouter::PromptTemplate.new(<<~TEMPLATE)
        Analyze this {{content_type}}: {{content}}

        Provide your analysis in the requested JSON format.
        Focus on: {{focus_areas}}
      TEMPLATE

      prompt = template.render(
        content_type: "text",
        content: "Machine learning is revolutionizing many industries by enabling automated decision-making and pattern recognition.",
        focus_areas: "key concepts and impact"
      )

      response = client.complete(
        [{ role: "user", content: prompt }],
        model: "openai/gpt-4o-mini",
        response_format: response_format,
        extras: { max_tokens: 300 }
      )

      structured = response.structured_output
      expect(structured).to be_a(Hash)
      expect(structured).to have_key("summary")
      expect(structured).to have_key("confidence")
      expect(structured).to have_key("key_points")
    end
  end

  describe "template performance and caching" do
    it "handles large template rendering efficiently", vcr: { cassette_name: "prompt_template_performance" } do
      large_template = OpenRouter::PromptTemplate.new(<<~TEMPLATE)
        System: {{system_prompt}}

        {{#each items}}
        Item {{@index}}: {{this.name}}
        Description: {{this.description}}
        Category: {{this.category}}

        {{/each}}

        Instructions: {{instructions}}
      TEMPLATE

      items = (1..20).map do |i|
        {
          name: "Item #{i}",
          description: "Description for item #{i}",
          category: "Category #{(i % 3) + 1}"
        }
      end

      start_time = Time.now
      prompt = large_template.render(
        system_prompt: "You are a helpful assistant",
        items: items,
        instructions: "Please analyze these items"
      )
      render_time = Time.now - start_time

      response = client.complete(
        [{ role: "system", content: prompt }, { role: "user", content: "Summarize the items" }],
        model: "openai/gpt-3.5-turbo",
        extras: { max_tokens: 200 }
      )

      expect(render_time).to be < 1.0 # Should render quickly
      expect(prompt).to include("Item 1")
      expect(prompt).to include("Item 20")
      expect(response).to be_a(OpenRouter::Response)
    end
  end
end