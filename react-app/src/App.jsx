import React, { useState } from 'react';

export default function App() {
  const [activeTab, setActiveTab] = useState('overview');

  const clusterNodes = [
    { name: 'k8s-master-01', role: 'Control Plane / etcd', status: 'Ready', ip: '10.148.0.10', cpu: '2 vCPU', mem: '4 GB' },
    { name: 'k8s-worker-01', role: 'Worker (Traefik / Headlamp)', status: 'Ready', ip: '10.148.0.11', cpu: '2 vCPU', mem: '4 GB' },
    { name: 'k8s-worker-02', role: 'Worker (ArgoCD / React.js Workloads)', status: 'Ready', ip: '10.148.0.12', cpu: '2 vCPU', mem: '4 GB' },
  ];

  const services = [
    {
      title: 'Headlamp Dashboard',
      description: 'Kubernetes cluster operations & pod observability console',
      url: 'https://headlamp.dara.lifestyle',
      badge: 'v0.23.0',
      status: 'Active',
      color: '#3b82f6',
      icon: '☸️'
    },
    {
      title: 'ArgoCD GitOps',
      description: 'Declarative GitOps continuous deployment & sync automation',
      url: 'https://argocd.dara.lifestyle',
      badge: 'v2.11.0',
      status: 'Active',
      color: '#f97316',
      icon: '🐙'
    },
    {
      title: 'Traefik Ingress Controller',
      description: 'L7 Cloud-native reverse proxy & SSL termination engine',
      url: 'https://headlamp.dara.lifestyle',
      badge: 'v3.0.0',
      status: 'Active',
      color: '#06b6d4',
      icon: '🚦'
    },
    {
      title: 'React.js Production App',
      description: 'Single-page web application served via Nginx & GitOps pipeline',
      url: 'https://react.dara.lifestyle',
      badge: 'v1.0.0',
      status: 'Active',
      color: '#10b981',
      icon: '⚛️'
    }
  ];

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', backgroundColor: '#090d16', color: '#f8fafc' }}>
      {/* Top Navbar */}
      <header style={{
        backgroundColor: '#0f172a',
        borderBottom: '1px solid #1e293b',
        padding: '1rem 2rem',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div style={{
            width: '40px',
            height: '40px',
            borderRadius: '8px',
            background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '1.25rem',
            fontWeight: 'bold',
            boxShadow: '0 4px 12px rgba(59, 130, 246, 0.4)'
          }}>
            DL
          </div>
          <div>
            <h1 style={{ fontSize: '1.25rem', fontWeight: 700, margin: 0, letterSpacing: '-0.025em' }}>
              dara.lifestyle
            </h1>
            <p style={{ fontSize: '0.75rem', color: '#94a3b8', margin: 0 }}>
              Automated Kubernetes Infrastructure & GitOps Pipeline
            </p>
          </div>
        </div>

        <nav style={{ display: 'flex', gap: '1rem' }}>
          {['overview', 'nodes', 'cicd'].map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              style={{
                backgroundColor: activeTab === tab ? '#1e293b' : 'transparent',
                color: activeTab === tab ? '#38bdf8' : '#94a3b8',
                border: activeTab === tab ? '1px solid #38bdf8' : '1px solid transparent',
                borderRadius: '6px',
                padding: '0.5rem 1rem',
                fontSize: '0.875rem',
                fontWeight: 600,
                cursor: 'pointer',
                textTransform: 'capitalize',
                transition: 'all 0.2s'
              }}
            >
              {tab}
            </button>
          ))}
        </nav>
      </header>

      {/* Main Content Area */}
      <main style={{ flex: 1, padding: '2.5rem 2rem', maxWidth: '1200px', margin: '0 auto', width: '100%' }}>
        {activeTab === 'overview' && (
          <div>
            {/* Banner Section */}
            <div style={{
              background: 'linear-gradient(135deg, #1e1b4b 0%, #0f172a 100%)',
              border: '1px solid #312e81',
              borderRadius: '16px',
              padding: '2.5rem',
              marginBottom: '2.5rem',
              boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.5)'
            }}>
              <span style={{
                backgroundColor: '#3b82f620',
                color: '#60a5fa',
                padding: '0.25rem 0.75rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 600,
                border: '1px solid #3b82f640'
              }}>
                LAB 2 DEVOPS CLOUD ARCHITECTURE
              </span>
              <h2 style={{ fontSize: '2.25rem', fontWeight: 800, margin: '1rem 0 0.5rem 0' }}>
                Multi-Node Kubernetes on AWS with Kubespray & Ansible
              </h2>
              <p style={{ color: '#cbd5e1', fontSize: '1rem', maxWidth: '750px', lineHeight: 1.6 }}>
                Automated high-availability Kubernetes cluster managed via Infrastructure-as-Code. Integrated with Traefik Ingress routing, Let&apos;s Encrypt TLS certificates, Headlamp dashboard, and ArgoCD declarative GitOps continuous delivery.
              </p>
            </div>

            {/* Service Cards Grid */}
            <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.25rem' }}>
              Cluster Services & Endpoints
            </h3>
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
              gap: '1.5rem',
              marginBottom: '2.5rem'
            }}>
              {services.map((srv, idx) => (
                <div
                  key={idx}
                  style={{
                    backgroundColor: '#0f172a',
                    border: '1px solid #1e293b',
                    borderRadius: '12px',
                    padding: '1.5rem',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    boxShadow: '0 4px 6px -1px rgba(0,0,0,0.3)',
                    transition: 'transform 0.2s',
                  }}
                >
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                      <span style={{ fontSize: '1.75rem' }}>{srv.icon}</span>
                      <span style={{
                        backgroundColor: '#10b98120',
                        color: '#34d399',
                        fontSize: '0.75rem',
                        fontWeight: 600,
                        padding: '0.2rem 0.6rem',
                        borderRadius: '9999px',
                        border: '1px solid #10b98140'
                      }}>
                        {srv.status}
                      </span>
                    </div>
                    <h4 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.4rem' }}>{srv.title}</h4>
                    <p style={{ fontSize: '0.85rem', color: '#94a3b8', lineHeight: 1.5, marginBottom: '1rem' }}>{srv.description}</p>
                  </div>
                  <div>
                    <a
                      href={srv.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        width: '100%',
                        padding: '0.6rem 1rem',
                        backgroundColor: '#1e293b',
                        color: '#38bdf8',
                        textDecoration: 'none',
                        borderRadius: '8px',
                        fontSize: '0.85rem',
                        fontWeight: 600,
                        border: '1px solid #334155'
                      }}
                    >
                      Open {srv.title.split(' ')[0]} ↗
                    </a>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'nodes' && (
          <div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.25rem' }}>
              Kubernetes Cluster Topology (Kubespray Inventory)
            </h3>
            <div style={{
              backgroundColor: '#0f172a',
              border: '1px solid #1e293b',
              borderRadius: '12px',
              overflow: 'hidden',
              boxShadow: '0 4px 6px -1px rgba(0,0,0,0.3)'
            }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.9rem' }}>
                <thead>
                  <tr style={{ backgroundColor: '#1e293b', color: '#94a3b8', textTransform: 'uppercase', fontSize: '0.75rem', letterSpacing: '0.05em' }}>
                    <th style={{ padding: '1rem 1.25rem' }}>Node Hostname</th>
                    <th style={{ padding: '1rem 1.25rem' }}>Cluster Role</th>
                    <th style={{ padding: '1rem 1.25rem' }}>Internal IP</th>
                    <th style={{ padding: '1rem 1.25rem' }}>Hardware Specs</th>
                    <th style={{ padding: '1rem 1.25rem' }}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {clusterNodes.map((node, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid #1e293b' }}>
                      <td style={{ padding: '1rem 1.25rem', fontWeight: 600, color: '#f8fafc' }}>{node.name}</td>
                      <td style={{ padding: '1rem 1.25rem', color: '#cbd5e1' }}>{node.role}</td>
                      <td style={{ padding: '1rem 1.25rem', fontFamily: 'monospace', color: '#38bdf8' }}>{node.ip}</td>
                      <td style={{ padding: '1rem 1.25rem', color: '#94a3b8' }}>{node.cpu} / {node.mem}</td>
                      <td style={{ padding: '1rem 1.25rem' }}>
                        <span style={{
                          backgroundColor: '#10b98120',
                          color: '#34d399',
                          fontSize: '0.75rem',
                          fontWeight: 600,
                          padding: '0.2rem 0.6rem',
                          borderRadius: '9999px',
                          border: '1px solid #10b98140'
                        }}>
                          {node.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {activeTab === 'cicd' && (
          <div>
            <h3 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '1.25rem' }}>
              GitOps CI/CD Automation Flow
            </h3>
            <div style={{
              backgroundColor: '#0f172a',
              border: '1px solid #1e293b',
              borderRadius: '12px',
              padding: '2rem',
              boxShadow: '0 4px 6px -1px rgba(0,0,0,0.3)'
            }}>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
                <div style={{ backgroundColor: '#1e293b', padding: '1.25rem', borderRadius: '8px' }}>
                  <div style={{ color: '#38bdf8', fontWeight: 700, fontSize: '0.85rem', marginBottom: '0.5rem' }}>STAGE 1</div>
                  <h4 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Developer Push</h4>
                  <p style={{ fontSize: '0.85rem', color: '#94a3b8' }}>Code pushed to GitHub repository trigger CI/CD workflow.</p>
                </div>
                <div style={{ backgroundColor: '#1e293b', padding: '1.25rem', borderRadius: '8px' }}>
                  <div style={{ color: '#38bdf8', fontWeight: 700, fontSize: '0.85rem', marginBottom: '0.5rem' }}>STAGE 2</div>
                  <h4 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Docker Build & Tag</h4>
                  <p style={{ fontSize: '0.85rem', color: '#94a3b8' }}>Multi-stage container build and pushed to Container Registry.</p>
                </div>
                <div style={{ backgroundColor: '#1e293b', padding: '1.25rem', borderRadius: '8px' }}>
                  <div style={{ color: '#38bdf8', fontWeight: 700, fontSize: '0.85rem', marginBottom: '0.5rem' }}>STAGE 3</div>
                  <h4 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>GitOps Manifest Update</h4>
                  <p style={{ fontSize: '0.85rem', color: '#94a3b8' }}>Deployment image tag updated in GitOps repository.</p>
                </div>
                <div style={{ backgroundColor: '#1e293b', padding: '1.25rem', borderRadius: '8px' }}>
                  <div style={{ color: '#10b981', fontWeight: 700, fontSize: '0.85rem', marginBottom: '0.5rem' }}>STAGE 4</div>
                  <h4 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>ArgoCD Sync</h4>
                  <p style={{ fontSize: '0.85rem', color: '#94a3b8' }}>ArgoCD reconciles cluster state and rolls out zero-downtime update.</p>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer style={{
        backgroundColor: '#0f172a',
        borderTop: '1px solid #1e293b',
        padding: '1.5rem 2rem',
        textAlign: 'center',
        fontSize: '0.85rem',
        color: '#64748b'
      }}>
        © 2026 dara.lifestyle — Automated Kubernetes DevOps Lab with Ansible, Kubespray & ArgoCD
      </footer>
    </div>
  );
}
