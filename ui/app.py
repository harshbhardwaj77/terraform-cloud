import os, json, re, tempfile, subprocess, base64
import streamlit as st
import hcl2

# ========= Config =========
INFRA_DIR = os.path.abspath("../infra")   # adjust if needed
VARIABLES_TF = os.path.join(INFRA_DIR, "variables.tf")

# Common GCP regions and zones (extend as you like)
REGIONS = {
    "us-central1": ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f"],
    "us-east1":    ["us-east1-b", "us-east1-c", "us-east1-d"],
    "us-west1":    ["us-west1-a", "us-west1-b", "us-west1-c"],
    "europe-west1":["europe-west1-b", "europe-west1-c", "europe-west1-d"],
    "asia-south1": ["asia-south1-a", "asia-south1-b", "asia-south1-c"],
    "asia-southeast1": ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"],
}

st.set_page_config(page_title="Terraform App Console", layout="wide")
st.title("Terraform App Console")

# ========= Sidebar: Environment & Options =========
st.sidebar.header("Environment")
env = st.sidebar.selectbox("Workspace", ["dev", "stage", "prod"], index=0)
apply_only_if_changes = st.sidebar.checkbox("Apply only if the plan has changes", value=True)
st.sidebar.caption("Tip: Workspaces isolate state by env. We'll select/create a TF workspace with this name.")

# ========= Helpers =========
def run_stream(cmd, cwd=None, title="Command"):
    """Run subprocess and stream output live into an expander."""
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
        ok, _, _ = run_stream(["terraform", "workspace", "new", workspace_name], cwd=INFRA_DIR, title=f"terraform workspace new {workspace_name}")
        if not ok:
            return False
    else:
        ok, _, _ = run_stream(["terraform", "workspace", "select", workspace_name], cwd=INFRA_DIR, title=f"terraform workspace select {workspace_name}")
        if not ok:
            return False
    return True

# ---- robust HCL parsing helpers ----
def _first_dict(x):
    """Return a dict whether x is already a dict or a list[dict]."""
    if isinstance(x, dict):
        return x
    if isinstance(x, list):
        for item in x:
            if isinstance(item, dict):
                return item
    return {}

def load_variables_tf(path):
    with open(path, "r", encoding="utf-8") as f:
        obj = hcl2.load(f)
    vars_list = []
    for block in obj.get("variable", []):
        for name, attrs in block.items():
            attrs = _first_dict(attrs)
            vars_list.append({"name": name, "attrs": attrs})
    return vars_list

def extract_allowed_values(attrs):
    """Find contains([ ... ], var.x) inside validation.condition (dict or list)."""
    validation = attrs.get("validation")
    if validation is None:
        return None
    validation = _first_dict(validation)
    cond = validation.get("condition")
    if cond is None:
        return None
    try:
        s = json.dumps(cond)
    except Exception:
        s = str(cond)
    m = re.search(r"contains\(\s*\[([^\]]+)\]", s)
    if not m:
        return None
    inside = m.group(1)
    vals = re.findall(r'"([^"]+)"', inside)
    return vals or None

def looks_secret(name):
    return any(k in name.lower() for k in ["password","pass","secret","token","key","credentials","private"])

def default_from_attrs(attrs):
    if "default" not in attrs:
        return None
    d = attrs["default"]
    if isinstance(d, list) and len(d) == 0:
        return None
    return d

def detect_plan_has_changes(plan_stdout: str) -> bool:
    if "No changes." in plan_stdout:
        return False
    m = re.search(r"Plan:\s+(\d+)\s+to add,\s+(\d+)\s+to change,\s+(\d+)\s+to destroy\.", plan_stdout)
    if not m:
        # If we can't parse, assume there might be changes so we don't skip wrongly
        return True
    adds, changes, destroys = map(int, m.groups())
    return (adds + changes + destroys) > 0

# ========= Parse variables.tf =========
try:
    var_blocks = load_variables_tf(VARIABLES_TF)
except Exception as e:
    st.error(f"Failed to read variables from {VARIABLES_TF}: {e}")
    st.stop()

st.caption(f"Loaded variables from `{VARIABLES_TF}`")

# Pull defaults (if present) so we can seed region/zone
defaults = {vb["name"]: default_from_attrs(_first_dict(vb["attrs"])) for vb in var_blocks}
region_default = defaults.get("region") or "us-central1"
zone_default = defaults.get("zone") or (REGIONS.get(region_default, ["us-central1-a"])[0])

# ========= Dynamic form =========
with st.form("tf_form"):
    st.subheader("Variables")

    values = {}
    uploaded_sa = None

    # We'll keep track of selected region to drive the zone dropdown,
    # but still write into 'values' so Terraform gets it.
    selected_region_placeholder = st.empty()
    selected_zone_placeholder = st.empty()

    # First pass: render all variables with special-casing for region/zone/instance_name
    for vb in var_blocks:
        name = vb["name"]
        attrs = _first_dict(vb["attrs"])  # normalize
        vtype = attrs.get("type", "string")
        default = default_from_attrs(attrs)
        allowed = extract_allowed_values(attrs)

        if isinstance(vtype, list):
            vtype = "".join(str(x) for x in vtype)

        label = f"{name}"
        help_txt = attrs.get("description", "")

        # Special handler for SA JSON
        if name == "GOOGLE_CREDENTIALS_JSON":
            st.markdown("**Google Credentials**")
            st.write("Upload raw Service Account JSON (auto base64) or paste base64 directly.")
            uploaded_sa = st.file_uploader("Upload service account JSON", type=["json"], key="sa_json")
            manual_val = st.text_area("Or paste base64-encoded SA JSON", value="", key="sa_b64")
            values[name] = manual_val.strip()
            if uploaded_sa and not values[name]:
                try:
                    raw = uploaded_sa.read()
                    values[name] = base64.b64encode(raw).decode("utf-8")
                    st.success("Encoded uploaded JSON to base64 for GOOGLE_CREDENTIALS_JSON.")
                except Exception as e:
                    st.error(f"Failed to encode uploaded SA JSON: {e}")
            continue

        # Special UX for region
        if name == "region":
            regions_list = sorted(REGIONS.keys())
            try:
                idx = regions_list.index(default if default in regions_list else region_default)
            except ValueError:
                idx = 0
            sel_region = selected_region_placeholder.selectbox("region", regions_list, index=idx, help=help_txt, key="__region__")
            values["region"] = sel_region
            continue

        # Special UX for zone (depends on region)
        if name == "zone":
            current_region = values.get("region", region_default)
            zones_list = REGIONS.get(current_region, [zone_default])
            try:
                zidx = zones_list.index(default if default in zones_list else zone_default)
            except ValueError:
                zidx = 0
            sel_zone = selected_zone_placeholder.selectbox("zone", zones_list, index=zidx, help=help_txt, key="__zone__")
            values["zone"] = sel_zone
            continue

        # Nice text field for instance_name (if you declared it in variables.tf)
        if name == "instance_name":
            init = str(default) if isinstance(default, str) else "terraform-instance"
            values[name] = st.text_input("instance_name", value=init, help=help_txt, key="__instance_name__")
            continue

        # Generic renders
        if allowed:
            default_idx = allowed.index(default) if (isinstance(default, str) and default in allowed) else 0
            values[name] = st.selectbox(label, allowed, index=default_idx, help=help_txt, key=name)
        elif "bool" in str(vtype):
            init = bool(default) if isinstance(default, bool) else False
            values[name] = st.checkbox(label, value=init, help=help_txt, key=name)
        elif "number" in str(vtype):
            init = default if isinstance(default, (int, float)) else 0
            values[name] = st.number_input(label, value=init, help=help_txt, key=name)
        else:
            init = str(default) if isinstance(default, str) else ""
            if looks_secret(name):
                values[name] = st.text_input(label, value=init, help=help_txt, type="password", key=name)
            else:
                values[name] = st.text_input(label, value=init, help=help_txt, key=name)

    # Action row
    col1, col2, col3, col4 = st.columns([1,1,1,2])
    with col1:
        action = st.selectbox("Action", ["plan & apply", "plan only", "destroy"])
    with col2:
        run_btn = st.form_submit_button("Run")
    with col3:
        st.write("")  # spacer
    with col4:
        destroy_confirm = st.checkbox("Confirm destroy (when selected)", value=False)

# ========= Execute =========
if run_btn:
    # Required checks: any variable without default must be provided
    missing = []
    for vb in var_blocks:
        name = vb["name"]
        attrs = _first_dict(vb["attrs"])
        if "default" not in attrs:
            if values.get(name) in (None, "", []):
                missing.append(name)
    if missing and action != "destroy":
        st.error("Missing required variables: " + ", ".join(missing))
        st.stop()

    # Ensure the workspace for selected env
    ok, _, _ = run_stream(["terraform", "init", "-upgrade"], cwd=INFRA_DIR, title="terraform init")
    if not ok:
        st.stop()
    if not ensure_workspace(env):
        st.stop()

    # Write temp tfvars JSON (even for destroy, so required vars exist)
    with tempfile.NamedTemporaryFile("w", suffix=".auto.tfvars.json", delete=False) as f:
        json.dump(values, f)
        tfvars_path = f.name

    if action == "plan only":
        ok, _, _ = run_stream(["terraform", "plan", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform plan")
        if ok:
            st.success("Plan completed ✅")

    elif action == "destroy":
        if not destroy_confirm:
            st.error("Please tick 'Confirm destroy' to run destroy.")
            st.stop()
        # Show a destroy plan first (nice UX), then auto-approve destroy
        run_stream(["terraform", "plan", "-destroy", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform plan -destroy")
        ok, _, _ = run_stream(["terraform", "destroy", "-auto-approve", "-input=false", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform destroy")
        if ok:
            st.success("Destroy completed ✅")

    else:  # plan & apply
        ok, plan_out, _ = run_stream(["terraform", "plan", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform plan")
        if not ok:
            st.stop()
        has_changes = detect_plan_has_changes(plan_out)
        if apply_only_if_changes and not has_changes:
            st.warning("No changes detected. Skipping apply (per setting).")
        else:
            ok, _, _ = run_stream(["terraform", "apply", "-auto-approve", "-input=false", f"-var-file={tfvars_path}"], cwd=INFRA_DIR, title="terraform apply")
            if ok:
                st.success("Apply completed 🎉")
