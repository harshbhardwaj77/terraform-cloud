import os, json, re, tempfile, subprocess, base64
import streamlit as st
import hcl2

# ========= Config =========
INFRA_DIR = os.path.abspath("../infra")
VARIABLES_TF = os.path.join(INFRA_DIR, "variables.tf")

REGIONS = {
    "us-central1": ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f"],
    "us-east1":    ["us-east1-b", "us-east1-c", "us-east1-d"],
    "us-west1":    ["us-west1-a", "us-west1-b", "us-west1-c"],
    "europe-west1":["europe-west1-b", "europe-west1-c", "europe-west1-d"],
    "asia-south1": ["asia-south1-a", "asia-south1-b", "asia-south1-c"],
    "asia-southeast1": ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"],
}

st.set_page_config(page_title="Terraform CloudPanel Setup", layout="wide")
st.title("Terraform VM with CloudPanel")

st.sidebar.header("Environment")
env = st.sidebar.selectbox("Workspace", ["dev", "stage", "prod"], index=0)
apply_only_if_changes = st.sidebar.checkbox("Apply only if the plan has changes", value=True)

# ========= Terraform Generator =========
def generate_main_tf() -> str:
    return '''terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = base64decode(var.GOOGLE_CREDENTIALS_JSON)
}

resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = file("${path.module}/install-cloudpanel.sh")

  metadata = {
    ssh-keys = "terraform:${var.ssh_public_key}"
  }
}'''

# ========= Helpers =========
def run_stream(cmd, cwd=None, title="Command"):
    exp = st.expander(f"🔧 {title}", expanded=True)
    code = exp.empty()
    ps = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    lines = []
    for line in ps.stdout:
        lines.append(line.rstrip("\n"))
        code.code("\n".join(lines))
    ps.wait()
    ok = (ps.returncode == 0)
    if not ok:
        exp.error(f"Exit code: {ps.returncode}")
    return ok, "\n".join(lines), ""

def ensure_workspace(workspace_name):
    ok, out, _ = run_stream(["terraform", "workspace", "list"], cwd=INFRA_DIR, title="terraform workspace list")
    if not ok:
        return False
    if not re.search(rf"(^|\s){re.escape(workspace_name)}(\s|$)", out):
        return run_stream(["terraform", "workspace", "new", workspace_name], cwd=INFRA_DIR, title=f"terraform workspace new {workspace_name}")[0]
    else:
        return run_stream(["terraform", "workspace", "select", workspace_name], cwd=INFRA_DIR, title=f"terraform workspace select {workspace_name}")[0]

def _first_dict(x):
    if isinstance(x, dict): return x
    if isinstance(x, list):
        for item in x:
            if isinstance(item, dict): return item
    return {}

def load_variables_tf(path):
    with open(path, "r", encoding="utf-8") as f:
        obj = hcl2.load(f)
    return [{"name": name, "attrs": _first_dict(attrs)} for block in obj.get("variable", []) for name, attrs in block.items()]

def extract_allowed_values(attrs):
    cond = _first_dict(attrs.get("validation", {})).get("condition")
    if cond is None: return None
    s = json.dumps(cond)
    m = re.search(r"contains\(\s*\[([^\]]+)\]", s)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else None

def default_from_attrs(attrs):
    return None if "default" not in attrs else attrs["default"]

def looks_secret(name):
    return any(k in name.lower() for k in ["password","pass","secret","token","key","credentials","private"])

def detect_plan_has_changes(out):
    m = re.search(r"Plan:\s+(\d+)\s+to add,\s+(\d+)\s+to change,\s+(\d+)\s+to destroy", out)
    return True if not m else sum(map(int, m.groups())) > 0

# ========= Load variables =========
try:
    var_blocks = load_variables_tf(VARIABLES_TF)
except Exception as e:
    st.error(f"Failed to read variables from {VARIABLES_TF}: {e}")
    st.stop()

defaults = {vb["name"]: default_from_attrs(_first_dict(vb["attrs"])) for vb in var_blocks}
region_default = defaults.get("region") or "us-central1"
zone_default = defaults.get("zone") or REGIONS.get(region_default, ["us-central1-a"])[0]

# ========= Form =========
with st.form("tf_form"):
    st.subheader("Variables")
    values = {}
    uploaded_sa = None

    selected_region_placeholder = st.empty()
    selected_zone_placeholder = st.empty()

    for vb in var_blocks:
        name = vb["name"]
        attrs = _first_dict(vb["attrs"])
        default = default_from_attrs(attrs)
        allowed = extract_allowed_values(attrs)

        if name == "GOOGLE_CREDENTIALS_JSON":
            uploaded_sa = st.file_uploader("Upload SA JSON", type=["json"])
            manual_val = st.text_area("Or paste base64-encoded SA JSON", value="")
            values[name] = manual_val.strip()
            if uploaded_sa and not values[name]:
                values[name] = base64.b64encode(uploaded_sa.read()).decode("utf-8")
            continue

        if name == "region":
            regions = sorted(REGIONS.keys())
            idx = regions.index(default) if default in regions else 0
            sel_region = selected_region_placeholder.selectbox("region", regions, index=idx, key="__region__")
            values["region"] = sel_region
            continue

        if name == "zone":
            current_region = values.get("region", region_default)
            zones_list = REGIONS.get(current_region, [zone_default])
            zidx = zones_list.index(default) if default in zones_list else 0
            sel_zone = selected_zone_placeholder.selectbox("zone", zones_list, index=zidx, key="__zone__")
            values["zone"] = sel_zone
            continue

        values[name] = st.text_input(name, value=default or "", type="password" if looks_secret(name) else "default")

    action = st.selectbox("Action", ["plan & apply", "plan only", "destroy"])
    destroy_confirm = st.checkbox("Confirm destroy (for destroy only)", value=False)
    run_btn = st.form_submit_button("Run")

if run_btn:
    with open(os.path.join(INFRA_DIR, "main.tf"), "w") as f:
        f.write(generate_main_tf())

    ok, _, _ = run_stream(["terraform", "init", "-upgrade"], cwd=INFRA_DIR, title="terraform init")
    if not ok or not ensure_workspace(env):
        st.stop()

    with tempfile.NamedTemporaryFile("w", suffix=".auto.tfvars.json", delete=False) as f:
        json.dump(values, f)
        tfvars_path = f.name

    if action == "plan only":
        ok, _, _ = run_stream(["terraform", "plan", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform plan")
        if ok:
            st.success("Plan completed ✅")

    elif action == "destroy":
        if not destroy_confirm:
            st.error("Please confirm destroy checkbox.")
            st.stop()
        run_stream(["terraform", "plan", "-destroy", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform plan -destroy")
        ok, _, _ = run_stream(["terraform", "destroy", "-auto-approve", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform destroy")
        if ok:
            st.success("Destroy completed ✅")

    else:
        ok, plan_out, _ = run_stream(["terraform", "plan", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform plan")
        if not ok:
            st.stop()
        if apply_only_if_changes and not detect_plan_has_changes(plan_out):
            st.warning("No changes detected. Skipping apply.")
        else:
            ok, _, _ = run_stream(["terraform", "apply", "-auto-approve", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform apply")
            if ok:
                st.success("Apply completed 🎉")
