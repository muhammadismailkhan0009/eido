const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const {
  LanguageClient,
  TransportKind
} = require('vscode-languageclient/node');

let client;
let output;

function workspaceRoot() {
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (!folder) {
    throw new Error('Open an Eido workspace first.');
  }
  return folder.uri.fsPath;
}

function configuration() {
  return vscode.workspace.getConfiguration('eido');
}

function executableName(name) {
  return process.platform === 'win32' ? name + '.exe' : name;
}

function findWorkspaceTool(names) {
  let directory = workspaceRoot();

  while (true) {
    for (const name of names) {
      const candidate = path.join(directory, executableName(name));
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    }

    const parent = path.dirname(directory);
    if (parent === directory) {
      return undefined;
    }
    directory = parent;
  }
}

function resolveTool(setting, fallback, localNames) {
  const configured = configuration().get(setting, '').trim();
  return configured || findWorkspaceTool(localNames) || fallback;
}

function runProcess(command, args, cwd, label) {
  return new Promise((resolve, reject) => {
    output ??= vscode.window.createOutputChannel('Eido');
    output.show(true);
    output.appendLine('> ' + command + ' ' + args.join(' '));

    const child = spawn(command, args, {
      cwd,
      shell: false
    });

    child.stdout.on('data', chunk => output.append(chunk.toString()));
    child.stderr.on('data', chunk => output.append(chunk.toString()));
    child.on('error', reject);
    child.on('close', code => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(label + ' failed with exit code ' + code));
      }
    });
  });
}

async function checkProject() {
  const root = workspaceRoot();
  const compiler = resolveTool('compiler.path', 'eido', ['eido', 'bin/eido']);
  await runProcess(
    compiler,
    ['check', path.join(root, 'module.yaml')],
    root,
    'Eido check'
  );
  vscode.window.showInformationMessage('Eido check passed.');
}

async function buildProject() {
  const root = workspaceRoot();
  const compiler = resolveTool('compiler.path', 'eido', ['eido', 'bin/eido']);
  const relativeOutput = configuration().get('build.output', '.eido/bin/app');
  const outputPath = path.resolve(root, relativeOutput);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });

  await runProcess(
    compiler,
    ['build', path.join(root, 'module.yaml'), '-o', outputPath],
    root,
    'Eido build'
  );

  vscode.window.showInformationMessage('Built ' + outputPath);
  return outputPath;
}

async function runProject() {
  const root = workspaceRoot();
  const outputPath = await buildProject();
  await runProcess(outputPath, [], root, 'Eido program');
}

function registerCommand(context, command, operation) {
  context.subscriptions.push(
    vscode.commands.registerCommand(command, async () => {
      try {
        await operation();
      } catch (error) {
        vscode.window.showErrorMessage(String(error.message ?? error));
      }
    })
  );
}

async function activate(context) {
  output = vscode.window.createOutputChannel('Eido');
  context.subscriptions.push(output);

  const serverCommand = resolveTool('server.path', 'eido-lsp', ['eido-lsp']);
  const serverOptions = {
    command: serverCommand,
    args: [],
    transport: TransportKind.stdio
  };
  const clientOptions = {
    documentSelector: [
      { scheme: 'file', language: 'eido' }
    ],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher('**/module.yaml')
    }
  };

  client = new LanguageClient(
    'eido',
    'Eido Language Server',
    serverOptions,
    clientOptions
  );

  context.subscriptions.push(client);
  await client.start();

  registerCommand(context, 'eido.check', checkProject);
  registerCommand(context, 'eido.build', buildProject);
  registerCommand(context, 'eido.run', runProject);
}

async function deactivate() {
  if (client) {
    await client.stop();
  }
}

module.exports = {
  activate,
  deactivate
};
