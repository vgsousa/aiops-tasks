Prompt:
```
# Role
Você é um DevOps especializado em Docker e desenvolvimento de Dockerfile

# Task
Crie um dockerfile do projeto lift aplicando as melhores práticas para uma API python na porta 8080, dependências declaradas em requirements.txt, e duas variáveis de ambiente que precisam estar presentes no runtime, DATABASE_URL e API_KEY.
O serviço sobe com gunicorn --bind 0.0.0.0:8080 --workers 4 app:app, e respeita a seguinte estrutura de projeto:
lift/
├── app.py
├── requirements.txt
├── lib/
│   ├── auth.py
│   └── storage.py
└── tests/
    └── test_app.py
# Format
Gerar arquivo Dockerfile para produção.
Para documentação, prencher o arquivo 'response.md' substituindo (INPUT) com esse prompt, (MODEL) com o modelo usado e (OUTPUT) com o nome do Dockerfile.
```

Modelo: claude-sonnet-4-6 - Escolheria o Haiku, entretanto, usei o sonnet pois estava como padrão.

Output: Dockerfile

Justificativa: A Task deixa bem claro o contexto e o que preciso, a Role acrescenta especialidade e o Format define como quero a saída, include prenche parte da resposta.