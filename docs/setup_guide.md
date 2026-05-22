# 🛠️ Pre-Workshop Setup Guide

Please complete these steps **before the session** so we can hit the ground running.

---

## 1 — Python

Make sure you have Python 3.10 or later installed.

```bash
python --version
# Python 3.10.x or higher
```

If not, install via [python.org](https://www.python.org/downloads/) or use `uv` (see below — it can install Python for you).

---

## 2 — uv

`uv` is the package manager we use throughout the workshop.

**macOS / Linux:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc   # or source ~/.zshrc
uv --version
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
uv --version
```

---

## 3 — Git

```bash
git --version
```

If missing: [git-scm.com/downloads](https://git-scm.com/downloads)

Configure your identity:
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

---

## 4 — Docker (for Notebook 05 only)

Install Docker Desktop from [docker.com/get-started](https://www.docker.com/get-started/).

```bash
docker --version
docker run hello-world   # confirms it works
```

> ⚠️ Docker is only needed for Notebook 05. Skip for now if you run into trouble.

---

## 5 — OpenAI API key (for Notebook 02 only)

1. Create an account at [platform.openai.com](https://platform.openai.com)
2. Go to **API Keys** and create a new secret key
3. Add a small amount of credit (a few dollars is more than enough)
4. Keep the key safe — you will paste it into Google Colab's secret manager during the session

> ⚠️ Never commit API keys to GitHub.

---

## 6 — Google Colab access

All notebooks run on [Google Colab](https://colab.research.google.com) — just a Google account is needed.

To open a notebook directly from this repo in Colab, click the **Open in Colab** badge at the top of each notebook.

---

## ✅ Checklist

- [ ] Python 3.10+
- [ ] `uv` installed and `uv --version` works
- [ ] `git` configured
- [ ] Docker Desktop installed and running (Notebook 05)
- [ ] OpenAI API key ready (Notebook 02)
- [ ] Google account for Colab
