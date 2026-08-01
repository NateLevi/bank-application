FROM public.ecr.aws/lambda/python:3.12

COPY requirements.txt ${LAMBDA_TASK_ROOT}/requirements.txt
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

COPY BankAPI.py ${LAMBDA_TASK_ROOT}/BankAPI.py
COPY models ${LAMBDA_TASK_ROOT}/models
COPY repositories ${LAMBDA_TASK_ROOT}/repositories
COPY services ${LAMBDA_TASK_ROOT}/services

CMD ["BankAPI.handler"]
