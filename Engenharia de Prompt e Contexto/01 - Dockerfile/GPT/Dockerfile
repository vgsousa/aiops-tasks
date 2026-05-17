FROM python:3.12-slim AS runtime

# Variáveis de ambiente padrão
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8080

# Diretório da aplicação
WORKDIR /app

# Instala dependências do sistema necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Cria usuário não-root
RUN useradd --create-home --shell /bin/bash appuser

# Copia apenas o arquivo de dependências primeiro
# para aproveitar cache de build
COPY requirements.txt .

# Atualiza pip e instala dependências Python
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copia código da aplicação
COPY . .

# Ajusta permissões
RUN chown -R appuser:appuser /app

# Usa usuário não-root
USER appuser

# Expõe porta da API
EXPOSE 8080

# Healthcheck simples
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080')" || exit 1

# Validação de variáveis obrigatórias + start da aplicação
CMD ["/bin/sh", "-c", "\
    test -n \"$DATABASE_URL\" || (echo 'DATABASE_URL is required' && exit 1); \
    test -n \"$API_KEY\" || (echo 'API_KEY is required' && exit 1); \
    exec gunicorn --bind 0.0.0.0:8080 --workers 4 app:app \
"]